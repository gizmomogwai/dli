import std.stdio;
import std.traits;
import std.format;
import stdx.reflection;
import std.algorithm;
import std.typecons;
import std.meta;
unittest {
	
}

auto collectOptions(string[] args, ) {
  string[string] options;
  options["a"] = "b";

  string[] rest;
  rest ~= "abc";

  foreach (arg; args) {
    if (arg.startsWith("--")) {
      auto flagName = arg[2..$];
      options[flagName] = "true";
    } 
  }

  return tuple!("options", "rest")(options, rest);
}

unittest {
  import dunit.toolkit;
  auto res = collectOptions(["--force", "--verbose", "command1", "rest"]);
  res.options["force"].assertEqual("true");
  res.options["verbose"].assertEqual("true");
  ("not_in_options" in res.options).assertNull();
}
/+
class Dor {
  struct DorAttribute {
    string name;
    bool isOptional() {
      return false;
    }
  }

  enum Command;

  struct Optional {
    string name;
    bool isOptional() {
      return true;
    }
  }

  @Optional("opt1")
  @DorAttribute("normal")
  void task1(string name, string[string] options) {
    writeln("task1: ", name);
  }

  bool isOptional(string member)() {
    return hasUDA!(__traits(getMember, typeof(this), member), Optional);
  }

  static bool isCommand(T, string member)() {
    return hasUDA!(__traits(getMember, T, member), Command) &&
      __traits(isVirtualFunction, (__traits(getMember, T, member)));
  }

  static string generateStart(T) () {
    string res;
    res ~= "override void start(string[] args) {";
    res ~= "  auto res = collectOptions(args);";
    res ~= "  auto command = res.rest[0];";
    res ~= "  switch (command) {";
    foreach (member; __traits(allMembers, T)) {
      static if (isCommand!(T, member)) {
        res ~= "    case \"" ~ member ~ "\": "~member~"();break;";
      }
    }
    res ~= "    default: throw new Exception(\"unknown command: \" ~ command);";
    res ~= "  }";
    res ~= "}";
    return res;
  }

  abstract void start(string[] command);
}


class Dor2 : Dor {
  @Command void hello() {
    writeln("hello");
  }

  @Command void hello2() {
    writeln("hello2");
  }

  mixin(generateStart!(typeof(this)));
}

class Dor3 : Dor2 {
  @Command void hello3() {
    writeln("hello3");
  }

  mixin(generateStart!(typeof(this)));
}

int main(string[] args) {
  Dor dor = new Dor3();
  dor.start(args);
  return 0;
}
+/
int main(string[] args) {
  return 0;
}

