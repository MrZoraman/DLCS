module dlcs.parsing;
import std.stdio;

abstract class SyntaxParserBase
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

class ElementParser : SyntaxParserBase
{
    public this(string pathElement)
    {
        super(pathElement);
    }
    
    protected override void iterate(in int index, in char c)
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

class SpaceParser : SyntaxParserBase
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

class ParseFailException : Exception
{
private:
    int[] _parseFailIndexes;
    immutable string _problemSyntax;

public:
    this(string message, string problemSyntax, int[] parseFailIndexes...) pure
    {
        super(message);
        _parseFailIndexes = parseFailIndexes;
        _problemSyntax = problemSyntax;
        
        import std.algorithm.sorting : sort;
        sort(_parseFailIndexes);
    }
    
    string problemSyntax() pure const @property
    {
        return _problemSyntax;
    }
    
    void printInfo(File stream)
    {
        stream.writeln(_problemSyntax);
        stream.writeln(makeProblemArrows());
    }
    
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