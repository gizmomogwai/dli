import std.stdio;
import std.traits;
import std.format;
import std.algorithm;
import std.typecons;
import std.meta;
import std.traits;
import std.string;

struct Option {
  string name;
  string value;
  this(string expression) {
    auto idx = expression.indexOf('=');
    if (idx == -1) {
      name = expression;
      value = "true";
    } else {
      name = expression[0..idx];
      value = expression[idx+1..$];
    }
  }
}

unittest {
  import dunit.toolkit;
  auto optionWithoutValue = Option("test");
  optionWithoutValue.name.assertEqual("test");
  optionWithoutValue.value.assertEqual("true");

  auto optionWithValue = Option("test=1");
  optionWithValue.name.assertEqual("test");
  optionWithValue.value.assertEqual("1");
}

struct Command {
  string name;
  Option[string] options;
}

bool finishOptionParsing(string arg) {
  return arg == "-";
}

bool isOption(string arg) {
  return arg.startsWith("--");
}

string getOptionExpression(string arg) {
  return arg[2..$];
}

/++
 + Parses options for commands on the commandline.
 + The pattern is [global options] [command [options]]* [- rest]
 + @return Tuple of options and rest of unparsed arguments
 +/
auto collectCommands(string[] args) {
  Command[] commands;
  string[] rest = args;

  string currentCommand = "";
  Option[string] currentOptions;
  foreach (arg; args) {
    if (arg.finishOptionParsing()) {
      rest = rest[1..$];
      break;
    }

    if (arg.isOption()) {
      Option o = Option(arg.getOptionExpression());
      currentOptions[o.name] = o;
    } else {
      // its a command
      commands ~= Command(currentCommand, currentOptions);
      currentCommand = arg;
      currentOptions = currentOptions.init;
    }
    rest = rest[1..$];
  }
  commands ~= Command(currentCommand, currentOptions);
  return tuple!("commands", "rest")(commands, rest);
}

/// checking global options, commands and rest
unittest {
  import dunit.toolkit;
  auto res = collectCommands(["--force", "--verbose", "command1", "--quiet", "-", "rest"]);

  // global command
  auto global = res.commands[0];
  global.name.assertEqual("");

  // global options
  global.options.length.assertEqual(2);
  auto o1 = global.options["force"];
  o1.name.assertEqual("force");
  o1.value.assertEqual("true");
  auto o2 = global.options["verbose"];
  o2.name.assertEqual("verbose");
  o2.value.assertEqual("true");
  ("not_in_options" in global.options).assertNull();

  // first command
  auto command1 = res.commands[1];
  command1.name.assertEqual("command1");

  // and options
  command1.options.length.assertEqual(1);
  auto o3 = command1.options["quiet"];
  o3.name.assertEqual("quiet");
  o3.value.assertEqual("true");

  // checking rest
  writeln(res.rest);
  res.rest.length.assertEqual(1);
  res.rest[0].assertEqual("rest");

}

/// checking no globals, command with options, no rest
unittest {
  import dunit.toolkit;
  auto res = collectCommands(["command1", "--quiet"]);

  res.commands.length.assertEqual(2);
  auto command1 = res.commands[1];
  command1.name.assertEqual("command1");
  auto o1 = command1.options["quiet"];
  o1.name.assertEqual("quiet");
  o1.value.assertEqual("true");
}


class DLI {

  enum Command;

  private static bool isCommand(T, string member)() {
    return hasUDA!(__traits(getMember, T, member), Command) &&
      __traits(isVirtualFunction, (__traits(getMember, T, member)));
  }

  private static string createHasOptionMethod(T)() {
    string res;
    res ~= "override bool hasOption(string command, string optionName) {\n";
    res ~= "  writeln(\"hasOption \" ~command ~ \", \" ~ optionName);\n";
    res ~= "  switch (command) {\n";
    foreach (member; __traits(allMembers, T)) {
      static if (isCommand!(T, member)) {
        res ~= "    case \"" ~ member ~ "\":\n";
        res ~= "      switch (optionName) {\n";
        foreach (parameterIdentifier; ParameterIdentifierTuple!(__traits(getMember, T, member))[0..$-1]) {
          res ~= "        case \"" ~ parameterIdentifier ~ "\": return true;\n";
        }
        res ~= "        default: throw new Exception(\"option '\" ~ optionName ~ \"' not found\");\n";
        res ~= "      } // switch(optionName)\n";
      }
    }
    res ~= "    default: throw new Exception(\"command '\" ~ command ~ \"' not found\");\n";
    res ~= "  } // switch(command)\n";
    res ~= "} // hasOption\n";
    return res;
  }

  protected abstract bool hasOption(string command, string option);

  private static string createStartMethod(T)() {
    string res;
    res ~= "override void start(string[] args) {\n";
    res ~= "  auto res = collectCommands(args);\n";
    res ~= "  writeln(\"rest:\", res);\n";
    res ~= "  auto command = res.commands[1];\n";
    res ~= "  switch (command.name) {\n";
    foreach (member; __traits(allMembers, T)) {
      static if (isCommand!(T, member)) {
        res ~= "    case \"" ~ member ~ "\":\n";
        string[] defaults;
        foreach (parameterIdentifier; (ParameterIdentifierTuple!(__traits(getMember, T, member)))[0..$-1]) {
          defaults ~= "      if (!(\"" ~ parameterIdentifier ~ "\" in command.options)) {command.options[\"" ~ parameterIdentifier ~"\"] = Option(\"" ~parameterIdentifier ~ "=false\");}\n";
        }
        res ~= defaults.join();
        res ~= "      " ~ member ~ "(";
        string[] args;
        foreach (parameterIdentifier; (ParameterIdentifierTuple!(__traits(getMember, T, member)))[0..$-1]) {
          args ~= ("command.options[\"" ~ parameterIdentifier ~ "\"].value");
        }
        args ~= "res.rest";
        res ~= args.join(", ") ~ ");\n";
        res ~= "      break;\n";
      }
    }
    res ~= "    default: throw new Exception(\"unknown command: \" ~ command.name);\n";
    res ~= "  } // switch \n";
    res ~= "} // start\n";
    return res;
  }

  public abstract void start(string[] command);

  public static string dli(T)() {
    return createHasOptionMethod!T() ~ createStartMethod!T();
  }

}

class Git : DLI {
  @Command void rebase(string interactive, string[] what ...) {
    writeln("git rebase",
            interactive == "true" ? " -i " : " ",
            what);
  }
  pragma(msg, dli!(typeof(this)));
  mixin(dli!(typeof(this)));
}

unittest {
  DLI git = new Git();
  git.start("rebase --interactive - a b c".split(" "));
  git.start("rebase - a b c".split(" "));
}
version (unittest) {
  int main(string[] args) {
    return 0;
  }
} else {
  int main(string[] args) {
    DLI git = new Git();
    /+
     import net.masterthought.rainbow.r;
     writeln("\u2714".rainbow.green);
     writeln("\u2718".rainbow.red);
     +/
    git.start(args[1..$]);
    return 0;
  }
}
