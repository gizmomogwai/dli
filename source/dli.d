module dli;

import std.stdio;
import std.traits;
import std.format;
import std.algorithm;
import std.typecons;
import std.meta;
import std.traits;
import std.string;
import dunit.toolkit;

class Option {
  string name;
  string shortname;
  string description;
  string value;
  string defaultValue;
  private this(string n, string v) {
    name = n;
    value = v;
    defaultValue = "false";
  }

  private this(string n) {
    this(n, "false");
  }

  static Option fromExpression(string expression) {
    auto idx = expression.indexOf('=');
    string name;
    string value;
    if (idx == -1) {
      name = expression;
      value = "true";
    } else {
      name = expression[0..idx];
      value = expression[idx+1..$];
    }
    return new Option(name, value);
  }

  void setValue(string v) {
    value = v;
  }

  string getValue() {
    if (value != null) {
      return value;
    }

    return defaultValue;
  }
  override string toString() {
    return format("--%s (%s)", name, defaultValue);
  }
}

unittest {
  auto tested = new Option("t", "false");
  tested.getValue().assertEqual("false");
  tested.setValue("ttt");
  tested.getValue().assertEqual("ttt");
}

static bool hasAttribute(T, S, string member)() {
  static if (__traits(hasMember, T, member)) {
    return hasUDA!(__traits(getMember, T, member), S);
  } else {
    return false;
  }
}

template foreachMemberWithAttribute(T, A) {
  string foreachMemberWithAttribute(string function(string) dg) {
    string res;
    foreach (member; __traits(allMembers, T)) {
      static if (hasAttribute!(T, A, member)) {
        res ~= dg(member);
      }
    }
    return res;
  }
}

unittest {
  class Testerle {
    @Option int aVariable;
    @Task void aMethod() {
    }
  }
  foreachMemberWithAttribute!(Testerle, Option)(s => s).assertEqual("aVariable");
  foreachMemberWithAttribute!(Testerle, Task)(s => s).assertEqual("aMethod");
}

string createTaskInfo(T, string member)() {
  string res;
  res ~= "  {\n    Option[] options;\n";
  foreach (parameterIdentifier; ParameterIdentifierTuple!(__traits(getMember, T, member))) {
    res ~= "    options ~= new Option(\"" ~ parameterIdentifier ~ "\");\n";
  }
  res ~= "    res.add(new TaskInfo(\"" ~ member ~ "\", \"\", options));\n  }\n";
  return res;
}

string createTransformStaticToRuntimeMethod(T)() {
  string res;
  res ~= "override protected Tasks transformStaticToRuntime() {\n";
  res ~= "  Tasks res = new Tasks();\n";
  res ~= foreachMemberWithAttribute!(T, Option)
    (member => "  res.add(new Option(\"" ~ member ~ "\"));\n");
  foreach (member; __traits(allMembers, T)) {
    static if (hasAttribute!(T, Task, member)) {
      res ~= createTaskInfo!(T, member);
    }
  }
  res ~= "  return res;\n";
  res ~= "}\n";
  return res;
}

string createExecute(T)() {
  string res;
  res ~= "override void execute(TaskInfo ti) {\n";
  res ~= foreachMemberWithAttribute!(T, Option)
    (member => "  " ~ member ~ " = tasks.getOption(\"" ~ member ~ "\").value;\n");

  res ~= "  switch (ti.name) {\n";
  foreach (member; __traits(allMembers, T)) {
    static if (hasAttribute!(T, Task, member)) {
      res ~= "    case \"" ~ member ~ "\":\n";

      string[] h;
      foreach (parameterIdentifier; ParameterIdentifierTuple!(__traits(getMember, T, member))) {
        h ~= "      ti.get(\"" ~ parameterIdentifier ~ "\").value";
      }
      res ~= "      " ~ member ~ "(" ~ h.join(", ") ~ ");\n";
      res ~= "      break;\n";
    }
  }
  res ~= "    default: throw new Exception(format(\"cannot work with '%s'\", ti.name));\n";
  res ~= "  }\n";
  res ~= "}\n";
  return res;
}

bool isOption(string arg) {
  return arg.startsWith("--");
}

string createDli(T)() {
  string res;
  res ~= createTransformStaticToRuntimeMethod!(T)();
  res ~= createExecute!(T)();
  return res;
}

string toString(Option[] options, int offset) {
  string res;
  foreach (option; options) {
    res ~= format("  %s\n", option.toString());
  }
  return res;
}

class TaskInfo {
  string name;

  string description;

  Option[] options;

  this(string n, string d, Option[] o) {
    name = n;
    description = d;
    options = o;
  }

  bool has(string name) {
    return options.canFind!("a.name == b")(name);
  }

  Option get(string name) {
    return options.find!("a.name == b")(name)[0];
  }

  override string toString() {
    return format("%s - %s\n%s", name, description, options.toString(2));
  }
}

private unittest {
  Option[] options;
  auto o1 = new Option("name1", "value1");
  options ~= o1;
  auto o2 = new Option("name2", "value2");
  options ~= o2;
  TaskInfo tested = new TaskInfo("name", "desc", options);
  tested.has("name1").assertTrue();
  tested.get("name1").assertEqual(o1);
  tested.has("name2").assertTrue();
  tested.get("name2").assertEqual(o2);
  tested.has("name3").assertFalse();
}

/++
 + manages all tasks known to the system.
 + the information what tasks are in the
 + system must be collected at compile time.
 +/
public class Tasks {
  TaskInfo[string] tasks;
  public Option[string] options;

  public this() {
  }

  TaskInfo get(string name) {
    return tasks[name];
  }

  bool has(string name) {
    return (name in tasks) != null;
  }

  void add(TaskInfo t) {
    tasks[t.name] = t;
  }

  void add(Option o) {
    options[o.name] = o;
  }

  bool hasOption(string name) {
    return (name in options) != null;
  }

  Option getOption(string name) {
    return options[name];
  }

  override string toString() {
    foreach (t; tasks) {
      writeln(t);
    }
    return "";
  }
}

struct Task {
}

class Dli {
  Tasks tasks;
  this() {
    tasks = transformStaticToRuntime();
  }

  protected abstract Tasks transformStaticToRuntime();

  public @Task void help() {
    writeln(tasks);
  }

  public abstract void execute(TaskInfo ti);

    private auto getCommand(T)(T parseResult) {
    if (parseResult.commands.length == 1) {
      throw new Exception("no command given");
    }

    if (parseResult.commands.length > 2) {
      throw new Exception("only on command at a time");
    }

    // check if task is known
    auto command = parseResult.commands[1];
    if (!tasks.has(command.name)) {
      throw new Exception("unknown command \"" ~ command.name ~ "\"");
    }
    return command;
  }

  private void applyGlobalOptions(T)(T parseResult) {
    auto global = parseResult.commands[0];
    foreach (o; global.options) {
      if (!tasks.hasOption(o.name)) {
        throw new Exception("unknown option: \"" ~ o.name ~ "\"");
      } else {
        tasks.getOption(o.name).value = o.value;
      }
    }
  }
  private auto applyTaskOptions(T, U)(T parseResult, U command) {
    auto task = tasks.get(command.name);
    foreach (o; command.options) {
      if (!task.has(o.name)) {
        throw new Exception(format("unknown option \"%s\" for command \"%s\"", o.name, command.name));
      }
      task.get(o.name).value = o.value;
    }
    return task;
  }

  public void start(string[] args) {
    auto parseResult = parse(args);
    applyGlobalOptions(parseResult);
    auto task = applyTaskOptions(parseResult, getCommand(parseResult));
    execute(task);
  }

}

struct Command {
  string name;
  Option[string] options;
}

bool finishOptionParsing(string arg) {
  return arg == "-" || arg == "--";
}

string getOptionExpression(string arg) {
  return arg[2..$];
}

/++
 + Parses options for commands on the commandline.
 + The pattern is [global options] [command [options]]* [- rest]
 + @return Tuple of options and rest of unparsed arguments
 +/
auto parse(string[] args) {
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
      Option o = Option.fromExpression(arg.getOptionExpression());
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
  auto res = parse(["--force", "--verbose", "command1", "--quiet", "-", "rest"]);

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
  auto res = parse(["command1", "--quiet"]);

  res.commands.length.assertEqual(2);
  auto command1 = res.commands[1];
  command1.name.assertEqual("command1");
  auto o1 = command1.options["quiet"];
  o1.name.assertEqual("quiet");
  o1.value.assertEqual("true");
}
