import 'dart:convert';
import 'dart:math';

class GraphManager {
  Map<int, List<double>> nodes = {};
  Map<int, Map<int, double>> edges = {};

  void parseGeoJson(String geoJsonData) {
    var decodedData = jsonDecode(geoJsonData);
    var features = decodedData['features'] as List<dynamic>;
    int nodeId = 0;

    for (var feature in features) {
      var coordinates = feature['geometry']['coordinates'] as List<dynamic>;
      for (int i = 0; i < coordinates.length - 1; i++) {
        int nodeA = nodeId++;
        int nodeB = nodeId++;
        nodes[nodeA] = [coordinates[i][0], coordinates[i][1]];
        nodes[nodeB] = [coordinates[i + 1][0], coordinates[i + 1][1]];
        double distance = calculateDistance(coordinates[i], coordinates[i + 1]);
        edges.putIfAbsent(nodeA, () => {});
        edges.putIfAbsent(nodeB, () => {});
        edges[nodeA]![nodeB] = distance;
        edges[nodeB]![nodeA] = distance;
      }
    }
  }

  double calculateDistance(List<dynamic> pointA, List<dynamic> pointB) {
    const double R = 6371; // Earth's radius in km
    double lat1 = pointA[1], lon1 = pointA[0];
    double lat2 = pointB[1], lon2 = pointB[0];
    double dLat = _toRad(lat2 - lat1), dLon = _toRad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double degree) => degree * (pi / 180);

  int findNearestNode(double latitude, double longitude) {
    int closestNode = -1;
    double minDistance = double.infinity;
    nodes.forEach((node, coords) {
      double dist = calculateDistance([longitude, latitude], coords);
      if (dist < minDistance) {
        minDistance = dist;
        closestNode = node;
      }
    });
    return closestNode;
  }

  List<int> findShortestPath(
      double startLatitude, double startLongitude, double endLatitude, double endLongitude) {
    int startNode = findNearestNode(startLatitude, startLongitude);
    int endNode = findNearestNode(endLatitude, endLongitude);
    if (startNode == -1 || endNode == -1) throw Exception("Node not found.");
    return Dijkstra.findPathFromGraph(edges, startNode, endNode) ?? [];
  }

  List<List<double>> getPathCoordinates(List<int> path) =>
      path.map((id) => nodes[id]!).toList();
}

class Dijkstra {
  static List<int>? findPathFromGraph(
      Map<int, Map<int, double>> graph, int start, int goal) {
    Map<int, double> distances = {};
    Map<int, int?> previous = {};
    List<int> unvisited = [];

    graph.keys.forEach((node) {
      distances[node] = double.infinity;
      previous[node] = null;
      unvisited.add(node);
    });
    distances[start] = 0;

    while (unvisited.isNotEmpty) {
      int? current = unvisited.reduce((a, b) =>
          distances[a]! < distances[b]! ? a : b);
      if (current == goal) {
        List<int> path = [];
        while (current != null) {
          path.insert(0, current);
          current = previous[current];
        }
        return path;
      }
      unvisited.remove(current);
      graph[current]?.forEach((neighbor, weight) {
        double tentative = distances[current]! + weight;
        if (tentative < distances[neighbor]!) {
          distances[neighbor] = tentative;
          previous[neighbor] = current;
        }
      });
    }
    return null;
  }
}
