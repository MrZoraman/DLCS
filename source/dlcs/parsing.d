module dlcs.parsing;
import std.stdio;

package abstract class SyntaxParserBase
{
private:
    string _builder;
    string[] _elements;
	
public:
    this(const string script) pure nothrow
    {
        _script = script;
    }
	
protected:
    immutable string _script;

    abstract void iterate(in int index, in char c) pure;

    void finished() pure { }

    void flush() pure nothrow
    {
        if(_builder.length > 0)
        {
            _elements ~= _builder;
            _builder.length = 0;
        }
    }

    void push(in char c) pure nothrow
    {
        _builder ~= c;
    }
    
public:
    string[] parse() pure
    {
        for(int ii = 0; ii < _script.length; ++ii)
        {
            iterate(ii, _script[ii]);
        }
        
        finished();
        flush();
        
        return _elements;
    }
}

package class ElementParser : SyntaxParserBase
{
    public this(string pathElement)
    {
        super(pathElement);
    }
    
    protected override void iterate(in int index, in char c) pure
    {
        switch(c)
        {
            case '|':
                flush();
                break;
            default:
                push(c);
        }
    }
    
    unittest
    {
        ElementParser parser = new ElementParser("some|good|stuff");
        string[] result = parser.parse();
        assert(result == ["some", "good", "stuff"]);
    }
}

package class SpaceParser : SyntaxParserBase
{
public:
    this(string syntax)
    {
        super(syntax);
    }
    
private:
    bool _inBraces = false;
    int _openBraceIndex = 0;
    
protected:
    override void iterate(in int index, in char c)
    {
        switch(c)
        {
            case '{':
                if(_inBraces) throw new ParseFailException("Braces are already open!", _script, index, _openBraceIndex);
                _inBraces = true;
                _openBraceIndex = index;
                break;
            case '}':
                if(!_inBraces) throw new ParseFailException("Braces don't match!", _script, index);
                _inBraces = false;
                break;
            case ' ':
                if(!_inBraces)
                {
                    flush();
                    break;
                }
                goto default;
            default:
                push(c);
        }
    }
    
    override void finished()
    {
        if(_inBraces) throw new ParseFailException("Braces are still open!", _script, _openBraceIndex);
    }
    
    unittest
    {
        import std.exception;
    
        SpaceParser parser = new SpaceParser("{foomf foomfah} toste");
        string[] result = parser.parse();
        assert(result == ["foomf foomfah", "toste"]);
        
        parser = new SpaceParser("{I am error{");
        assertThrown!ParseFailException(parser.parse());
        
        parser = new SpaceParser("I am{still error");
        assertThrown!ParseFailException(parser.parse);
    }
}


/**
    This exception is thrown if the command system experiences a parsing error.
*/
public class ParseFailException : Exception
{
private:
    int[] _parseFailIndexes;
    immutable string _problemSyntax;

    this(string message, string problemSyntax, int[] parseFailIndexes...) pure
    {
        super(message);
        _parseFailIndexes = parseFailIndexes;
        _problemSyntax = problemSyntax;
        
        import std.algorithm.sorting : sort;
        sort(_parseFailIndexes);
    }

public:
    /**
        Gets the command syntax that the parser failed to parse successfully.
        
        Returns:
            The syntax that caused the problem. This will equal what was ever 
            passed in the dlcs.dlcs.CommandSystem.registerCommand method.
    */
    string problemSyntax() pure const @property
    {
        return _problemSyntax;
    }
    
    /**
        Prints basic info to a file.
        
        This is a quick way to dump all of the exception's relevant info into a file.
        Info includes the syntax that failed to be parsed, the location of the errors
        and the stack trace. If this method does not format things to your liking, 
        this class offers the methods to build the error message yourself.
        
        Params:
            stream = The fhe file to output to.
    */
    void printInfo(File stream)
    {
        stream.writeln(_problemSyntax);
        stream.writeln(makeProblemArrows());
    }
    
    /**
        Makes a string that contains arrows that point directly to where the parser failed.
        
        If the string that is returned with this method is aligned with the problem syntax,
        the arrows will poin to the exact location where the parser failed.
        
        Params:
            arrow = The character to point to where the error occured.
            
        Returns:
            The string containing the arrows at the correct location. Arrows are separated
            by spaces.
    */
    string makeProblemArrows(char arrow = '^') pure
    {
        string result;
        result.length = _problemSyntax.length;
        
        int parseFailIndex = 0;
        for(int ii = 0; ii < _problemSyntax.length; ++ii)
        {
            if(_parseFailIndexes[parseFailIndex] == ii)
            {
                result ~= arrow;
                ++parseFailIndex;
            }
            else
            {
                result ~= ' ';
            }
        }
        return result;
    }
}