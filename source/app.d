module app;
import dli;

class Executor {
  public abstract void execute(string command);
}

class TestExecutor : Executor {
  string history;
  void execute(string command) {
    history ~= command;
  }
  void reset() {
    history = "";
  }
}

class RealExecutor : Executor {
  void execute(string command) {
    writeln(command);
  }
}

class Git : Dli {
  Executor executor;

  this(Executor e) {
    executor = e;
  }

  @Option string verbose;

  @Option string dryRun;

  @Task void add(string interactive) {
    executor.execute(format("add %s, %s, %s", verbose, dryRun, interactive));
  }

  @Task void remote(string interactive) {
    executor.execute(format("remote %s, %s, %s", verbose, dryRun, interactive));
  }

  mixin(createDli!(Git));

}

/// unknown options result in exceptions
unittest {
  auto history = new TestExecutor();
  auto tested = new Git(history);
  // unknown option
  tested.start(["--1"]).assertThrow();
  // option without command
  tested.start(["--verbose"]).assertThrow();


  // two commands
  tested.start(["command1", "command2"]).assertThrow();

  // unknown command
  tested.start(["help2"]).assertThrow();

  // unknown option for command
  tested.start(["--verbose", "add", "--unknownoption"]).assertThrow();

  // good
  history.reset();
  tested.start(["--verbose", "add", "--interactive"]);
  tested.tasks.getOption("verbose").value.assertEqual("true");
  tested.tasks.get("add").get("interactive").value.assertEqual("true");
  history.history.assertEqual("add true, false, true");
}


version (unittest) {
  int main(string[] args) {
    writeln("unittest main");
    return 0;
  }
} else {
  int main(string[] args) {
    auto git = new Git(new RealExecutor());
    git.start(args[1..$]);
    return 0;
  }
}
