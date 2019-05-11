import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.traits;
import std.conv;

struct PropsBase {
	Node*[] children;
}

struct DrawInfo {

}

struct Node {
	Component function(PropsBase* props) constructor = null;
	bool function(PropsBase* oldProps, PropsBase* newProps) propsHaveChanged = null;
	PropsBase* props = null;
	Component instance = null;
	auto instantiate() {
		instance = constructor(props);
		instance.componentDidMount();
		return instance;
	}

	auto needsUpdate() {
		return instance.needsUpdate;
	}

	auto updated() {
		instance.needsUpdate = false;
	}

	auto render() {
		if (needsUpdate()) {
			renderedChildren = instance.render().dup;
			updated();
		}
	}

	void updateProps(PropsBase* oldProps, PropsBase* newProps) {
		instance.updateProps(newProps);
		instance.componentDidUpdate(oldProps, newProps);
	}
	void draw() {
		instance.draw(&this);
	}

	string toString() {
		return "("~(instance is null ? "InstNull": instance.toString())~") \n"~
			renderedChildren.map!( x => ((x is null)? "(ChldNull)": x.toString()).tab()).join()
		~ "";
	}
	DrawInfo* drawInfo = null;
	Node*[] renderedChildren = [];
}

auto tab(string str) {
	return str.split("\n").map!(x => "\t"~x).join("\n");
}

class Component {
	static Component function(PropsBase* props) constructComponent;
	static bool function(PropsBase* oldProps, PropsBase* newProps) propsHaveChanged;
	abstract void updateProps(PropsBase* newProps);
	Node*[] render() {
		return null;
	};
	void componentDidUpdate(PropsBase* oldProps, PropsBase* newProps) {};
	void componentDidMount() {};
	void draw(Node* node) {
		foreach (i; node.renderedChildren) {
			if (i !is null) {
				i.drawInfo = node.drawInfo;
				i.draw();
			}
		}
	};
	public bool needsUpdate = true;
}

template defProps(alias props) {
	pure string propsDecl() {
		return "struct Props {
			PropsBase base;
			alias base this;
			"~props~"
		}";
	}

	mixin(propsDecl());

	pure string generatePropsHaveChanged() {
		auto member_comparisons = [__traits(allMembers, Props)]
			.map!((p) => "if ((cast(Props*)oldProps)."~p~" != (cast(Props*)newProps)."~p~") {return true;}")
			.join("\n");

		return "static propsHaveChanged(PropsBase* oldProps, PropsBase* newProps) {
			"~member_comparisons~"
			return false;
		}";
	}

	pure string defProps() {
		return propsDecl()~generatePropsHaveChanged()~"
			static Component constructComponent(PropsBase* props) {
				return (new typeof(this)(cast(Props*)props));
			}

			static Node* opCall(PropsBase* props) {
				//What's wrong about this such that it overwrites previous data in reconcile?
				return new Node(&constructComponent, &propsHaveChanged, props, null);
			}

			Props* props;

			override void updateProps(PropsBase* newProps) {
				props = cast(Props*)newProps;
			}

			override string toString() {
				return this.classinfo.to!string;
			}
			";
	}
}

template defState(alias state) {
	pure string stateDecl() {
		return "
		struct State {
			"~state~"
		}

		State* state;
		";
	}
	mixin(stateDecl());
	pure string defState() {
		return stateDecl()~[__traits(allMembers, State)]
			.map!((s) =>
				"
				@property auto "~s~"(typeof(state."~s~") value) {
					needsUpdate = true;
					return state."~s~" = value;
				}

				@property auto "~s~"() {
					return state."~s~";
				}
				"
			)
			.join("\n");
	}
}

//Uranium tag
template U(C, props...) {
	auto U(Node*[] children...) {
		//The tag seems to still reference the same memory for the oldNode
		//I think we'll need to copy away oldNodes so it won't be modified again...
		//I.e: double pointers for oldRenders
		return C(cast(PropsBase*)new C.Props(PropsBase(children), props));
	}
}

class Reactor {
	//Ok I think old renders need to put into references or something
	//they aren't persisting important data like their instance
	Node* oldRenderTree = null; //After rendering everything we'll move back here
	Node* newRenderTree;
	//We need to store the previous tree so we can diff them
	void render(Node* rootNode) {
		newRenderTree = reconcile(rootNode, oldRenderTree);
		newRenderTree.draw();
		oldRenderTree = newRenderTree;
	}

	//Perhaps double pointers here were a mistake?
	//Probably should do an array, right now children can be an array
	//so this architecture kinda doesn't make sense?
	Node* reconcile(Node* currentNode, Node* oldNode) {
		//Hang on, is this because renderedChildren is a pointer and we haven't reset it?
		Node* newNode = new Node();
		//If there is no oldNode or the constructors don't match create a new object
		if ((oldNode is null) || oldNode.constructor != currentNode.constructor) {
			currentNode.instantiate();
			*newNode = *currentNode;
		}
		//If the constructor is the same we shouldn't reconstruct
		else {
			*newNode = *oldNode;

			if (newNode.propsHaveChanged(oldNode.props, currentNode.props)) {
				newNode.updateProps(oldNode.props, currentNode.props);
			}
		}

		//So it looks like there's an old node that for some reason has no instantiation
		//which causes us to crash here
		newNode.render();

		//If they aren't the same renders, all of them need to be reinstantiated
		for (auto i = 0; i < newNode.renderedChildren.length; i++) {
			//This is being uninitialized at some point
			if (newNode.renderedChildren[i] !is null)
			{
				if (oldNode is null || newNode.renderedChildren.length != oldNode.renderedChildren.length) {
					newNode.renderedChildren[i] = reconcile(newNode.renderedChildren[i], null);
				} else {
					newNode.renderedChildren[i] = reconcile(newNode.renderedChildren[i], oldNode.renderedChildren[i]);
				}
			}
		}
		return newNode;
	}
}
