#ifndef NAVGRIDPATHFINDER_H
#define NAVGRIDPATHFINDER_H

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/a_star3d.hpp>
#include <queue>

namespace godot {

class NavGridPathFinder : public Node3D {
	GDCLASS(NavGridPathFinder, Node3D)

private:

protected:
	static void _bind_methods();

public:
	NavGridPathFinder();
	~NavGridPathFinder();

	PackedVector3Array get_point_path_cpp(AStar3D* astar, int start, int end);

	class ANode{
		public:
			ANode* parent;
			Vector3 position;
			int heapIndex = 0;
			int id = 0;
			float g = 0;
			float h = 0;
			float f = 0;
			
			ANode(ANode* par, Vector3 pos, int i){
				id = i;
				parent = par;
				position = pos;
			}
	};

	class ComparisonClass {
		public:
			bool operator() (ANode* a, ANode* b) {
				if (a->f > b->f)
					return true;
				else
					return false;
			}
	};
	
};

}

#endif