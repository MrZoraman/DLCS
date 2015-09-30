module dlcs.dlcs;

import dlcs.parsing;

import std.string : strip;
import std.uni : toLower;
import std.algorithm : canFind;
import std.array : split;
import std.stdio : File;

//debug import std.stdio : writeln;


class CommandResult(T)
{
public:
    T command;
    string[] preArgs;
    string[] args;
}

class SyntaxElement(T)
{
    enum TREE_SPACER = 4;
    bool _caseSensitive = false;
    
    protected T _command = null;

private:
    SyntaxElement!T[immutable(string)] _children;
    
    class SyntaxMatchPackage(T)
    {
        int matchIndex;
        SyntaxElement!T bestMatch;
        string wildCard;
    }
    
    SyntaxMatchPackage!T findBestMatch(string path)
    {
        //debug writeln("Searching for best match...");
        //debug writeln(path);
        
        if(path.length == 0) return null;
        
        immutable string[] childrenSyntaxPaths = _children.keys;
        
        int highestIndexMatch = 0;
        SyntaxElement!T bestMatch = null;
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
            SyntaxElement!T child = _children[path];
            
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
                _children[pathElement] = new SyntaxElement!T();
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
        SyntaxElement!T bestMatch = bestMatchPack.bestMatch;
        
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

class CommandSystem(T)
{
private:
    SyntaxElement!T _root = new SyntaxElement!T();
    T _unknownCommand = null;
    
public:
    void registerCommand(string syntax, T command)
    {
        SpaceParser parser = new SpaceParser(syntax);
        _root.addSyntax(parser.parse().idup, command);
    }
    
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
    
    void unknownCommand(T unknownCommand) @property
    {
        _unknownCommand = unknownCommand;
    } 
    
    T unknownCommand() @property
    {
        return _unknownCommand;
    }
    
    void printCommandTree(File stream)
    {
        immutable string unknownCommandString = unknownCommand is null
            ? "null"
            : typeof(unknownCommand).stringof;
            
        stream.writeln("UNKNOWN_COMMAND: ", unknownCommandString);
        _root.print(stream, 0);
    }
    
    bool caseSensitive() @property
    {
        return _root.isCaseSensitive;
    }
    
    void caseSensitive(bool caseSensitive) @property
    {
        _root.setCaseSensitive(caseSensitive);
    }
}