#include "navgridpathfinder.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void NavGridPathFinder::_bind_methods() {

	ClassDB::bind_method(D_METHOD("get_point_path_cpp", "astar", "start_pos", "end_pos"), &NavGridPathFinder::get_point_path_cpp);
}

NavGridPathFinder::NavGridPathFinder() {
	// Initialize any variables here.
}

NavGridPathFinder::~NavGridPathFinder() {
	// Add your cleanup here.
}

PackedVector3Array NavGridPathFinder::get_point_path_cpp(AStar3D* astar, int start, int end)
{
	// Create start and end node
	NavGridPathFinder::ANode startNode = NavGridPathFinder::ANode(nullptr, astar->get_point_position(start), start);
	NavGridPathFinder::ANode endNode = NavGridPathFinder::ANode(nullptr, astar->get_point_position(end), end);
	
	// List of node ids of previously traversed nodes
	std::vector<int> closedList = std::vector<int>();

	// Used to delete nodes poped from the open list heap
	std::vector<NavGridPathFinder::ANode*> popList = std::vector<NavGridPathFinder::ANode*>();

	// Add the start node
	std::priority_queue<ANode*, std::vector<ANode*>, NavGridPathFinder::ComparisonClass> openListHeap = std::priority_queue<ANode*, std::vector<ANode*>, NavGridPathFinder::ComparisonClass>();
	openListHeap.push(&startNode);

	int it = 0;
	while (openListHeap.empty() == false){

		NavGridPathFinder::ANode* currentNode = openListHeap.top();
		openListHeap.pop();

		closedList.push_back(currentNode->id);

		if (currentNode->id != start && currentNode->id != end)
			popList.push_back(currentNode);
		
		// Check if current is the target node, so we can end the loop and return the path
		if (currentNode->id == end) {

			PackedVector3Array path = PackedVector3Array();
			path.append(currentNode->position);

			while (currentNode->parent != nullptr){
				currentNode = currentNode->parent;
				path.append(currentNode->position);
			}

			while (openListHeap.empty() == false){
				delete(openListHeap.top());
				openListHeap.pop();
			}

			for (int i = 0; i < popList.size(); i++){
				delete(popList[i]);
			}
			popList.clear();

			path.reverse();
			return path;
		}

		// Look at all nodes connected to currentNode
		std::vector<NavGridPathFinder::ANode*> neighbors = std::vector<NavGridPathFinder::ANode*>();
		PackedInt64Array pointArr = astar->get_point_connections(currentNode->id);

		// Add connected nodes to "neighbors" vector
		for (int i = 0; i < pointArr.size(); i++){
			Vector3 node_position = astar->get_point_position(pointArr[i]);
			NavGridPathFinder::ANode* newNode = new NavGridPathFinder::ANode(currentNode, node_position, pointArr[i]);
			neighbors.push_back(newNode);
		}

		// Loop through neighbors
		for (int i = 0; i < neighbors.size(); i++){
			
			NavGridPathFinder::ANode* neighbor = neighbors[i];
			bool check_x = false;	

			if (check_x == false){
				// Calculate g, h, and f
				neighbor->g = currentNode->g + neighbor->position.distance_to(currentNode->position);
				neighbor->h = neighbor->position.distance_to(endNode.position);
				neighbor->f = neighbor->g + neighbor->h;

				// Check if neighbor is in the open list
				std::priority_queue<ANode*, std::vector<ANode*>, NavGridPathFinder::ComparisonClass> tmp = openListHeap;
				while(tmp.empty() == false){
					NavGridPathFinder::ANode* openNode = tmp.top();
					if (neighbor->id == openNode->id){
						check_x = true;
						break;
					}
					tmp.pop();
				}

				// Check if neighbor is in the closed list
				if (check_x == false){
					for (int j = 0; j < closedList.size(); j++){
						if (neighbor->id == closedList[j]){
							check_x = true;
							break;
						}
					}
				}
				// Add neighbor to open list if not already in the open list and not in the closed list
				if (check_x == false){
					NavGridPathFinder::ANode* newNode = new NavGridPathFinder::ANode(currentNode, neighbor->position, neighbor->id);
					newNode->g = neighbor->g;
					newNode->h = neighbor->h;
					newNode->f = neighbor->f;
					openListHeap.push(newNode);
				}
			}
		}

		// Freeing memory created by looking at connected nodes
		for (int i = 0; i < neighbors.size(); i++){
				delete(neighbors[i]);
		}
		neighbors.clear();
		
	}

	//If a path isn't found, the function returns (-999,-999,-999)
	
	while (openListHeap.empty() == false){
		delete(openListHeap.top());
		openListHeap.pop();
	}

	for (int i = 0; i < popList.size(); i++){
		delete(popList[i]);
	}
	popList.clear();
	
	return PackedVector3Array{Vector3(-999,-999,-999)};
	
}