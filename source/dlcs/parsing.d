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