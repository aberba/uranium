import std.traits;
import std.stdio;
import std.string;
import std.algorithm;
import std.typecons;
//Need a better way to stub

template Spy(T) {
  class Spy {
    T obj;

    void*[] calls = [];
    this(T obj) {
      this.obj = obj;
    }

    auto opDispatch(string name, A...)(A arguments) {
      calls ~= new Tuple!(string, A)(name, args);
      mixin("obj."~name~"(arguments);");
    }
  }
}

template Spy(alias fn) {
  class Spy {
    void*[] calls = [];

    auto opCall(A...)(A args) {
      calls ~= new Tuple!(A)(args);
      return fn(args);
    }

    auto wasCalled() {
      return call.length > 0;
    }
  }
}

auto test(int test, int anotherone) {
  writeln(test);
}
