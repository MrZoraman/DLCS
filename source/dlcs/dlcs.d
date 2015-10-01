module dlcs.dlcs;

import dlcs.parsing;

import std.string : strip;
import std.uni : toLower;
import std.algorithm : canFind;
import std.array : split;
import std.stdio : File;

//debug import std.stdio : writeln;

/**
    A package of relevant data returend by the command system given user input.
    
    This class acts as a container for the command itself, the preArgs and the
    args. This way, the user of the library can use this data however they want,
    allowing the library to be more flexible.
*/
public class CommandResult(T)
{
public:
    /**
        The command matched to the syntax by the command system.
        
        If no command was found, this will be null.
    */
    T command;
    
    /**
        The arguments that were read from the wildcards specified
        in the syntax.
    */
    string[] preArgs;
    
    /**
        The arguments that were trailing after the input after
        the best match was found and returned.
    */
    string[] args;
}

private class SyntaxElement(T)
{
    enum TREE_SPACER = 4;
    bool _caseSensitive = false;
    
    protected T _command = null;

private:
    SyntaxElement[immutable(string)] _children;
    
    class SyntaxMatchPackage(T)
    {
        int matchIndex;
        SyntaxElement bestMatch;
        string wildCard;
    }
    
    SyntaxMatchPackage!T findBestMatch(string path)
    {
        //debug writeln("Searching for best match...");
        //debug writeln(path);
        
        if(path.length == 0) return null;
        
        immutable string[] childrenSyntaxPaths = _children.keys;
        
        int highestIndexMatch = 0;
        SyntaxElement bestMatch = null;
        string wildCard;
        
        outer:
        foreach(childSyntaxPath; childrenSyntaxPaths)
        {
            //debug writeln("childSyntaxPath: ", childSyntaxPath);
        
            if(childSyntaxPath == "*") continue;
            
            int index = 0;
            while(index < childSyntaxPath.length && index < path.length)
            {
                immutable childChar = _caseSensitive
                    ? childSyntaxPath[index]
                    : cast(char)childSyntaxPath[index].toLower;
                immutable pathChar = _caseSensitive
                    ? path[index]
                    : cast(char)path[index].toLower;
                    
                if(childChar == pathChar)
                {
                    index++;
                }
                else if(childChar == ' ' || pathChar == ' ')
                {
                    continue outer;
                }
                else
                {
                    break;
                }
            }
            
            if(childSyntaxPath.length - 1 > index && childSyntaxPath[index + 1] != ' ')
            {
                continue;
            }
            
            if(index > highestIndexMatch)
            {
                highestIndexMatch = index;
                bestMatch = _children[childSyntaxPath];
            }
        }
        
        if(bestMatch is null)
        {
            if(childrenSyntaxPaths.canFind("*"))
            {
                bestMatch = _children["*"];
                string firstWord = getFirstWord(path);
                highestIndexMatch = firstWord.length;
                wildCard = firstWord;
            }
        }
        
        SyntaxMatchPackage!T pack = new SyntaxMatchPackage!T();
        pack.bestMatch = bestMatch;
        pack.matchIndex = highestIndexMatch;
        pack.wildCard = wildCard;
        return pack;
    }
    
    string getFirstWord(string str)
    {
        if(!str.canFind(' ')) return str;
        
        return str.split()[0];
    }
    
    void print(File stream, int level)
    {
        foreach(path; _children.keys)
        {
            printPreSpacing(stream, level);
            SyntaxElement child = _children[path];
            
            string commandString = child._command is null
                ? null
                : typeof(child._command).stringof;
                
            stream.writeln(path, ": ", commandString);
            child.print(stream, level + 1);
        }
    }
    
    void printPreSpacing(File stream, int level)
    {
        for(int spacesToPrint = 0; spacesToPrint < TREE_SPACER * level; spacesToPrint++)
        {
            stream.write(" ");
        }
    }

package:
    void addSyntax(immutable string[] path, T command)
    {
        if(path.length == 0)
        {
            _command = command;
            return;
        }
        
        ElementParser parser = new ElementParser(path[0]);
        string[] pathElements = parser.parse();
        immutable string[] subPath = path[1 .. $].idup;
        
        foreach(pathElement; pathElements)
        {
            if(pathElement !in _children)
            {
                _children[pathElement] = new SyntaxElement();
            }
            
            if(path.length > 1)
            {
                _children[pathElement].addSyntax(subPath, command);
            }
            else
            {
                _children[pathElement]._command = command;
            }
        }
    }
    
    CommandResult!T matchCommand(string path, string[] preArgs)
    {
        path = path.strip();
        SyntaxMatchPackage!T bestMatchPack = findBestMatch(path);
        
        if(bestMatchPack is null || bestMatchPack.bestMatch is null)
        {
            CommandResult!T result = new CommandResult!T();
            result.command = _command;
            result.args = path.split;
            result.preArgs = preArgs;
            return result;
        }
        
        if(bestMatchPack.wildCard !is null)
        {
            preArgs ~= bestMatchPack.wildCard;
        }
        
        immutable int matchIndex = bestMatchPack.matchIndex;
        SyntaxElement bestMatch = bestMatchPack.bestMatch;
        
        return bestMatch.matchCommand(path[matchIndex .. $].dup, preArgs);
    }

public:
    bool isCaseSensitive()
    {
        return _caseSensitive;
    }
    
    void setCaseSensitive(bool caseSensitive)
    {
        _caseSensitive = caseSensitive;
    }
}

/**
    Primary class for the library.
    
    Commands are submitted to the command system, and when given
    user input, it will try to produce the correct cooresponding
    command object.
    
    The template type must be a reference type!
*/
public class CommandSystem(T)
{
private:
    SyntaxElement!T _root = new SyntaxElement!T();
    T _unknownCommand = null;
    
public:
    /**
        registers a command to the command system.
        
        Params:
            syntax = This is the pattern that the command system
                will use to match the command with the user input.
                See the readme.md for examples. Command syntaxes
                can have various predefined arguments to make up
                complex command trees. To have the parser ignore spaces,
                put the arguments in curly braces. the parser will make
                sure the curly braces are used properly as to avoid
                mistakes made by the programmer. To have the command
                tree branch off into multiple aliases, use the rod symbol
                (|) to specify multiple command/parameter aliases.
                Wildcards can be specified for parameters by using a
                '*' symbol.
            command = The command that will be returned if user input 
                matches the specified syntax.
    */
    void registerCommand(string syntax, T command)
    {
        SpaceParser parser = new SpaceParser(syntax);
        _root.addSyntax(parser.parse().idup, command);
    }
    
    /**
        Matches user input to a given command and returns the result.
        
        Params:
            input = The user input. The command system will find the best
                match given the various syntaxes specified in the 
                registerCommand method.
    */
    CommandResult!T getCommand(string input)
    {
        CommandResult!T result = _root.matchCommand(input, []);
        
        if(result.command is null && _unknownCommand !is null)
        {
            result.args = input.split;
            result.preArgs = [];
            result.command = unknownCommand;
        }
        
        if(result.args.length > 0 && result.args[0] == "")
        {
            result.args = [];
        }
        
        return result;
    }
    
    /**
        Sets the command to be executed if the command system fails to find
        a command match.
        
        If the command system fails to find a match, this command will be
        executed. This can als,o be seen as the root node command, so if the
        user were to input a 'command' that is totally empty, this command
        will be executed. This is assuming an empty string wasn't registered
        as one of the commands.
        
        The arguments will be filled with whatever the user typed in.
        
        Params:
            unknownCommand = the command to execute when the command system
                cannot find a suitable command to execute.
    */
    void unknownCommand(T unknownCommand) @property
    {
        _unknownCommand = unknownCommand;
    } 
    
    /**
        Gets the unknown command.
        
        This returns the unknown command, or null if no unknown command has
        been set.
        
        Returns:
            The unknown command.
    */
    T unknownCommand() @property
    {
        return _unknownCommand;
    }
    
    /**
        Prints the command tree to a file.
        
        This prints out the structure of the command tree. It shows what
        the command system sees, so you can get an idea on the behavior
        of the command system when the user types in commands. This
        is intended to be a useful debugging tool.
        
        Params:
            stream = The file to output to.
    */
    void printCommandTree(File stream)
    {
        immutable string unknownCommandString = unknownCommand is null
            ? "null"
            : typeof(unknownCommand).stringof;
            
        stream.writeln("UNKNOWN_COMMAND: ", unknownCommandString);
        _root.print(stream, 0);
    }
    
    /**
        Checks if the command system is case sensitive or not.
        
        Returns:
            True if it is case sensitive, false if it is not case sensitive.
    */
    bool caseSensitive() @property
    {
        return _root.isCaseSensitive;
    }
    
    /**
        Sets if the command system is case sensitive or not.
        
        When the command system is not case sensitive, case will be ignored
        when matching the command. Arguments and preArguments will retain their
        case.
        
        Case sensitivity is set to false by default.
        
        Params:
            caseSensitive = If true, the command system will be case sensitive.
                If false, then it will not be.
    */
    void caseSensitive(bool caseSensitive) @property
    {
        _root.setCaseSensitive(caseSensitive);
    }
}