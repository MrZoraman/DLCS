module dlcs.parsing;
import std.stdio;

abstract class SyntaxParserBase
{
private:
    char[] _builder;
    string[] _elements;
	
public:
    this(immutable string script)
	{
        _script = script;
    }
	
protected:
    string _script;

    abstract void iterate(int index, char c);

    void finished() { }

    void flush()
    {
        if(_builder.length > 0)
        {
            _elements ~= _builder.idup;
            _builder.length = 0;
        }
    }

    void push(char c)
    {
        _builder ~= c;
    }
    
public:
    string[] parse()
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
    
    protected override void iterate(int index, char c)
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
    public this(string syntax)
    {
        super(syntax);
    }
    
    private bool inBraces = false;
    private int openBraceIndex = 0;
    
    protected override void iterate(int index, char c)
    {
        switch(c)
        {
            case '{':
                if(inBraces) throw new ParseFailException("Braces are already open!", _script, index, openBraceIndex);
                inBraces = true;
                openBraceIndex = index;
                break;
            case '}':
                if(!inBraces) throw new ParseFailException("Braces don't match!", _script, index);
                inBraces = false;
                break;
            case ' ':
                if(!inBraces)
                {
                    flush();
                    break;
                }
                goto default;
            default:
                push(c);
        }
    }
    
    unittest
    {
        import std.exception;
    
        SpaceParser parser = new SpaceParser("{foomf foomfah} toste");
        string[] result = parser.parse();
        assert(result == ["foomf foomfah", "toste"]);
        
        parser = new SpaceParser("{I am error{");
        assertThrown!ParseFailException(parser.parse());
    }
}

class ParseFailException : Exception
{
private:
    int[] _parseFailIndexes;
    string _problemSyntax;

public:
    this(string message, string problemSyntax, int[] parseFailIndexes...)
    {
        super(message);
        _parseFailIndexes = parseFailIndexes;
        _problemSyntax = problemSyntax;
        
        import std.algorithm.sorting : sort;
        sort(_parseFailIndexes);
    }
    
    string problemSyntax() const @property
    {
        return _problemSyntax;
    }
    
    void printInfo(File stream)
    {
        stream.writeln(_problemSyntax);
        stream.writeln(makeProblemArrows('^'));
    }
    
    string makeProblemArrows(char arrow)
    {
        char[] result;
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
        return result.idup;
    }
}