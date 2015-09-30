import std.stdio;
import std.string;

import dlcs.dlcs;

interface ICommand
{
    public void execute(string[] preArgs, string[] args);
}

class CommandTester : ICommand
{
    private string _str;
    
    public this(string str)
    {
        _str = str;
    }
    
    public override void execute(string[] preArgs, string[] args)
    {
        writeln("Command executed!");
        writeln("args.length: ", args.length);
        writeln("preArgs.length: ", preArgs.length);
        writeln("PreArgs: ", preArgs);
        writeln("args: ", args);
        writeln("Message: ", _str);
    }
    
    public override string toString() const
    {
        return "I am CommandTester: " ~  _str;
    }
}

void main()
{

    CommandSystem!ICommand lcs = new CommandSystem!ICommand();
    
    lcs.registerCommand("a", new CommandTester("Hello!"));
    lcs.registerCommand("a b", new CommandTester("Wah!"));
    lcs.registerCommand("b", new CommandTester("Hello again!"));
    lcs.registerCommand("b c|d", new CommandTester("woah!"));
    lcs.registerCommand("e f|g h", new CommandTester("dayum!"));
    lcs.registerCommand("i j|{k l} m", new CommandTester("woot!"));
    lcs.registerCommand("n * o", new CommandTester("the world is broken!"));
    lcs.registerCommand("p * q * s", new CommandTester("I don't even know at this point!"));
    lcs.registerCommand("t * * v", new CommandTester("why?!"));
    lcs.registerCommand("t * w v", new CommandTester("uwot"));
//            
//            lcs.registerCommand("x } oops", new CommandTester("oops"));
//            lcs.registerCommand("y {oops {", new CommandTester("woops"));
//            lcs.registerCommand("z { lady dady da", new CommandTester("dang"));
//        
    lcs.registerCommand("{home set}|sethome", new CommandTester("woot"));
    lcs.registerCommand("home", new CommandTester("weiew"));
    lcs.registerCommand("homenwinnigish", new CommandTester("Chicken n' winnigish"));
//            lcs.registerCommand("home", new CommandTester("weiew"));
    
            lcs.registerCommand("", new CommandTester("wot"));
    
    lcs.unknownCommand = new CommandTester("I have no clue what that is");
    
    lcs.printCommandTree(stdout);


    bool done = false;
    while(!done)
    {
        write("> ");
        string input = chomp(readln());
        
        writeln("INPUT: ", input);
        
        if(input == "exit")
        {
            done = true;
        }
        else
        {
            CommandResult!ICommand result = lcs.getCommand(input);
            if(result.command is null)
            {
                writeln("Command not found!");
            }
            else
            {
                result.command.execute(result.preArgs, result.args);
            }
        }
    }
}