module dlcs.dlcs;

import std.string : strip;
import std.uni : asLowerCase;
import std.algorithm : canFind;
import std.array : split;


class CommandResult(T)
{
public:
    T command;
    stringp[] preArgs;
    string[] args;
}

class SyntaxElement(T)
{
    enum TREE_SPACER = 4;
    shared static bool _caseSensitive = false;
    
    
    protected T _command = null;

private:
    string[T] _children;
    
    class SyntaxMatchPackage(T)
    {
        int matchIndex;
        SyntaxElement!T bestMatch;
        string wildCard;
    }
    
    SyntaxMatchPackage!T findBestMatch(string path)
    {
        if(path.length == 0) return null;
        
        string[] childrenSyntaxPaths = _children.keys;
        
        int highestInexMatch = 0;
        SyntaxElement!T bestMatch = null;
        string wildCard;
        
        outer:
        foreach(childSyntaxPath; childrenSyntaxPaths)
        {
            if(childSyntaxPath == "*") continue;
            
            int index = 0;
            while(index < childSyntaxPath.length && index < path.length)
            {
                char childChar = _caseSensitive
                    ? childSyntaxPath[index]
                    : childSyntaxPath[index].asLowerCase;
                char pathChar = _caseSensitive
                    ? path[index]
                    : path[index].asLowerCase;
                    
                if(childChar == ' ' || pathChar == ' ')
                {
                    continue outer;
                }
                else
                {
                    break;
                }
            }
            
            if(childSyntaxPath.length - 1 > index && childSyntaxPathChars[index + 1] != ' ')
            {
                continue;
            }
            
            if(index > highestInexMatch)
            {
                highestInexMatch = index;
                bestMatch = _children[childSyntaxPath];
            }
        }
        
        if(bestMatch is null)
        {
            if(childrenSyntaxPaths.canFind("*"))
            {
                bestMatch = _children["*"];
                string firstWord = getFirstWord(path);
                highestInexMatch = firstWord.length;
                wildCard = firstWord;
            }
        }
        
        SyntaxMatchPackage!T pack = new SyntaxMatchPackage!T();
        pack.bestMatch = bestMatch;
        pack.matchIndex = matchIndex;
        pack.wildcard = wildcard;
        return pack;
    }
    
    string getFirstWord(string str)
    {
        if(!str.canFind(' ')) return str;
        
        return str.split()[0];
    }
    
    void printPreSpacing(File stream, int level)
    {
        for(int spacesToPrint = 0; spacesToPrint < TREE_SPACER * level; spacesToPrint++)
        {
            stream.write(" ");
        }
    }

package:
    void addSyntax(string[] path, T command)
    {
        if(path.length == 0)
        {
            _command = command;
            return;
        }
        
        ElementParser parser = new ElementParser(path[0]);
        string[] pathElements = parser.parse();
        string[] subPath = path[1 .. $].dup;
        
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
    
    CommandResult matchCommand(string path, string[] preArgs)
    {
        path = path.strip();
        SyntaxMatchPackage!T bestMatchPack = findBestMatch(path);
        
        if(bestMatchPack is null || bestMatchPack.bestMatch is null)
        {
            CommandResult!T result = new CommandResult!T();
            result.command = _command;
            result.args = _path.split;
            result.preArgs = preArgs;
            return result;
        }
        
        if(bestMatchPack.wildCard !is null)
        {
            preArgs ~= bestMatchPack.wildCard;
        }
        
        int matchIndex = bestMatchPack.matchIndex;
        SyntaxElement!T bestMatch = bestMatchPack.bestMatch;
        
        return bestMatch.matchCommand(path[matchIndex .. $].dup, preArgs);
    }
public:
    static bool isCaseSensitive()
    {
        return caseSensitive;
    }
    
    static void setCaseSensitive(bool caseSensitive)
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
        _root.addSyntax(parser.parse(), command);
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
        
        if(result.args[0] == "")
        {
            result.args = [];
        }
        
        return result;
    }
    
    void unknownCommand(T unknownCommand) @property
    {
        _unknownCommand = unknownCommand;
    } 
    
    T unknownCommand() const @property
    {
        return _unknownCommand;
    }
    
    void printCommandTree(File stream)
    {
        string unknownCommandString = unknownCommand is null
            ? "null"
            : unknownCommand.stringof;
            
        stream.writeln("UNKNOWN_COMMAND: ", unknownCommandString);
        _root.print(stream, 0);
    }
    
    bool caseSensitive() const @property
    {
        return SyntaxElement.isCaseSensitive;
    }
    
    void caseSensitive(bool caseSensitive) @property
    {
        SyntaxElement.setCaseSensitive(caseSensitive);
    }
}