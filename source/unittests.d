unittest
{
    import std.stdio;
    import std.string;
    import std.exception;
    
    import dlcs.dlcs;
    import dlcs.parsing;
    
    class TestCommand
    {
        this(int id)
        {
            this.id = id;
        }
        
        public int id;
    }

    CommandSystem!TestCommand lcs = new CommandSystem!TestCommand();
    
    lcs.registerCommand("", new TestCommand(0));
    lcs.registerCommand("a", new TestCommand(1));
    lcs.registerCommand("a b", new TestCommand(2));
    lcs.registerCommand("b", new TestCommand(3));
    lcs.registerCommand("b c|d", new TestCommand(4));
    lcs.registerCommand("e f|g h", new TestCommand(5));
    lcs.registerCommand("i j|{k l} m", new TestCommand(6));
    lcs.registerCommand("n * o", new TestCommand(7));
    lcs.registerCommand("p * q * s", new TestCommand(8));
    lcs.registerCommand("t * * v", new TestCommand(9));
    lcs.registerCommand("t * w v", new TestCommand(10));
    
    lcs.unknownCommand = new TestCommand(-1);
    
    assert(lcs.getCommand("").command.id == 0);
    assert(lcs.getCommand("a").command.id == 1);
    assert(lcs.getCommand("a b").command.id == 2);
    assert(lcs.getCommand("b").command.id == 3);
    assert(lcs.getCommand("b c").command.id == 4);
    assert(lcs.getCommand("b d").command.id == 4);
    assert(lcs.getCommand("e f h").command.id == 5);
    assert(lcs.getCommand("e g h").command.id == 5);
    assert(lcs.getCommand("i j m").command.id == 6);
    assert(lcs.getCommand("i k l m").command.id == 6);
    assert(lcs.getCommand("n ? o").command.id == 7);
    assert(lcs.getCommand("p ? q ? s").command.id == 8);
    assert(lcs.getCommand("t ? ? v").command.id == 9);
    assert(lcs.getCommand("t ? w v").command.id == 10);
    assert(lcs.getCommand("err").command.id == -1);
    
    assert(lcs.getCommand("a 1 2 3").args == ["1", "2", "3"]);
    
    assert(lcs.getCommand("t 1 2 v").preArgs == ["1", "2"]);
    
    CommandResult!TestCommand c = lcs.getCommand("n ! o @");
    assert(c.command.id == 7);
    assert(c.args == ["@"]);
    assert(c.preArgs == ["!"]);
    
    TestCommand badCommand = new TestCommand(-2);
    assertThrown!ParseFailException(lcs.registerCommand("{i am error{", badCommand));
    assertThrown!ParseFailException(lcs.registerCommand("{i am also error", badCommand));
    assertThrown!ParseFailException(lcs.registerCommand("}i am bad as well", badCommand));
}

unittest
{
}