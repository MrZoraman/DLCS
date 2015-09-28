module dlcs.parsing;

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
    immutable string _script;

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
                if(inBraces) throw new Exception("fof");
                inBraces = true;
                openBraceIndex = index;
                break;
            case '}':
                if(!inBraces) throw new Exception("fof");
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
}

