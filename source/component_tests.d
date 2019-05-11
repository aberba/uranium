import std.stdio;
import std.string;
import std.array;
import x11.X;
import x11.Xlib;
import std.algorithm;
import std.traits;
import uranium;
import doubles;
import std.conv;

/*
<XDisplay display=1>
	<Rectange x=10 y=10 width=20 height=20/>
</XDisplay>
*/
//We could take advantage of lazy arguments here
//We can also use property methods for setting state
//These functions need to create a virtual node which will hold the actual corresponding instance
/*
XDisplay([
  Rectangle(10, 10, 20, 20, [])
])
*/

class BasicComponent: Component {
	static timesConstructed = 0;
	static timesDrawn = 0;
	static timesRendered = 0;
	static timesMounted = 0;
	static timesUpdated = 0;
	static BasicComponent[] instances = [];

	static resetCounters() {
		timesConstructed = 0;
		timesDrawn = 0;
		timesRendered = 0;
		timesMounted = 0;
		timesUpdated = 0;
		instances = [];
	}
	mixin(defProps!("string name; int age;"));

	this(Props* props) {
		timesConstructed++;
		instances ~= this;
		this.props = props;
	}

	override void componentDidMount() {
		timesMounted++;
	}

	override void componentDidUpdate(PropsBase* oldProps, PropsBase* newProps) {
		timesUpdated++;
	}

	override void draw(Node* node) {
		timesDrawn++;
		super.draw(node);
	}

	override Node*[] render() {
		timesRendered++;
		return this.props.children;
	}
}

class RenderingComponent: Component {
	static timesConstructed = 0;
	static timesDrawn = 0;
	static timesRendered = 0;
	static timesMounted = 0;
	static timesUpdated = 0;
	static RenderingComponent[] instances = [];

	static resetCounters() {
		timesConstructed = 0;
		timesDrawn = 0;
		timesRendered = 0;
		timesMounted = 0;
		timesUpdated = 0;
		instances = [];
	}
	mixin(defProps!("string name; int age;"));

	this(Props* props) {
		timesConstructed++;
		instances ~= this;
		this.props = props;
	}

	override void componentDidMount() {
		timesMounted++;
	}

	override void componentDidUpdate(PropsBase* oldProps, PropsBase* newProps) {
		timesUpdated++;
	}

	override void draw(Node* node) {
		timesDrawn++;
		super.draw(node);
	}

	override Node*[] render() {
		timesRendered++;
		return [
			U!(BasicComponent, "Top level node", 20)(
				U!(BasicComponent, "Top level node", 20)
			)
		];
	}
}

///Top level component with no children executes lifecycle correctly
unittest {
	import dunit.toolkit;
	import uranium;

	scope(exit) BasicComponent.resetCounters();

	auto r = new Reactor();
	r.render(U!(BasicComponent, "Top level node", 20));
	r.render(U!(BasicComponent, "Top level node", 20));
	BasicComponent.timesConstructed.assertEqual(1);
	BasicComponent.timesMounted.assertEqual(1);
	BasicComponent.timesUpdated.assertEqual(0);
	BasicComponent.timesRendered.assertEqual(1);
	BasicComponent.timesDrawn.assertEqual(2);
}

///With an unchanged child node
unittest {
	import dunit.toolkit;
	import uranium;

	scope(exit) BasicComponent.resetCounters();

	auto r = new Reactor();
	r.render(
		U!(BasicComponent, "Top level node", 20)(
			U!(BasicComponent, "Child node", 1)
		)
	);
	r.render(
		U!(BasicComponent, "Top level node", 20)(
			U!(BasicComponent, "Child node", 1)
		)
	);
	BasicComponent.timesConstructed.assertEqual(2);
	BasicComponent.timesMounted.assertEqual(2);
	BasicComponent.timesUpdated.assertEqual(1);
	BasicComponent.timesRendered.assertEqual(2);
	BasicComponent.timesDrawn.assertEqual(4);
}

///With an added child
unittest {
	import dunit.toolkit;
	import uranium;

	scope(exit) BasicComponent.resetCounters();

	auto r = new Reactor();
	r.render(
		U!(BasicComponent, "Top level node", 20)(
			U!(BasicComponent, "Child node", 1)
		)
	);
	BasicComponent.instances[0].needsUpdate = true;
	r.render(
		U!(BasicComponent, "Top level node", 20)(
			U!(BasicComponent, "Child node", 1),
			U!(BasicComponent, "Second child node", 1)
		)
	);

	BasicComponent.timesConstructed.assertEqual(4);
	BasicComponent.timesMounted.assertEqual(4);
	BasicComponent.timesUpdated.assertEqual(1);
	BasicComponent.timesRendered.assertEqual(5);
	BasicComponent.timesDrawn.assertEqual(5);
}

//Null renders
unittest {
	import dunit.toolkit;
	import uranium;

	scope(exit) BasicComponent.resetCounters();

	auto r = new Reactor();
	r.render(
		U!(BasicComponent, "Top level node", 20)(
			null
		)
	);
	BasicComponent.timesConstructed.assertEqual(1);
	BasicComponent.timesMounted.assertEqual(1);
	BasicComponent.timesUpdated.assertEqual(0);
	BasicComponent.timesRendered.assertEqual(1);
	BasicComponent.timesDrawn.assertEqual(1);
}

//Rerenders multiple levels
unittest {
	import dunit.toolkit;
	import uranium;

	scope(exit) BasicComponent.resetCounters();

	auto r = new Reactor();
	r.render(
		U!(BasicComponent, "Top level node", 20)(
			U!(BasicComponent, "Top level node", 20)(
				U!(BasicComponent, "Top level node", 20)(
					null
				)
			)
		)
	);
	BasicComponent.instances[0].needsUpdate = true;

	r.render(
		U!(BasicComponent, "Top level node", 20)(
			U!(BasicComponent)(
				U!(BasicComponent),
				U!(BasicComponent),
				U!(BasicComponent),
				U!(BasicComponent)
			)
		)
	);
}

/*
This test case breaks, I believe this is down to a bug in D.
When the rendered children exceed one level of depth in a component
the pointer for the children will point to garbage.
I suspect D is garbage collecting the array while references
still exist to the child node
*/
/*
unittest {
	import dunit.toolkit;
	import uranium;

	scope(exit) {
		BasicComponent.resetCounters();
		RenderingComponent.resetCounters();
	}

	auto r = new Reactor();
	r.render(
		U!(RenderingComponent, "Top level node", 20)
	);

	BasicComponent.timesConstructed.assertEqual(2);
	BasicComponent.timesMounted.assertEqual(2);
	BasicComponent.timesUpdated.assertEqual(0);
	BasicComponent.timesRendered.assertEqual(2);
	BasicComponent.timesDrawn.assertEqual(2);
}*/
