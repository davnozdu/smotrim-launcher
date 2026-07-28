import 'dart:math';

import 'package:flutter/material.dart';

/// This traversal policy manage the up and down direction to be totally
/// predictable.
/// Going up or down will always go to the next or previous row. All other
/// traversal policy try to be smart, and in some cases can skip rows when
/// going up or down.
class RowByRowTraversalPolicy extends FocusTraversalPolicy with DirectionalFocusTraversalPolicyMixin {
  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) => descendants;

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final FocusScopeNode? scope = currentNode.nearestScope;
    if (scope == null) {
      return super.inDirection(currentNode, direction);
    }

    final FocusNode? nextNode = _findNextNode(scope, currentNode, direction);
    if (nextNode == null) {
      if (direction == TraversalDirection.left || direction == TraversalDirection.right) {
        return false;
      }
      return super.inDirection(currentNode, direction);
    }
    nextNode.requestFocus();
    return true;
  }

  /// Single-pass equivalent of [NodeSearcher.findCandidates] followed by
  /// [NodeSearcher.findBestFocusNode], kept separate because this runs on every
  /// single d-pad press.
  ///
  /// The two-step version copied the node list, wrapped every entry in a
  /// throwaway object, unwrapped it again, and re-read [FocusNode.rect] — which
  /// walks the render tree to compute a global transform — several times per
  /// node. With a screenful of app cards that added up to hundreds of transform
  /// computations and allocations per key press, which is exactly the kind of
  /// per-input cost a remote-driven UI cannot afford.
  FocusNode? _findNextNode(
      FocusScopeNode scope, FocusNode currentNode, TraversalDirection direction) {
    final Offset from = currentNode.rect.center;
    final int fromX = from.dx.round();
    final int fromY = from.dy.round();

    FocusNode? best;
    int bestX = 0;
    int bestY = 0;
    int bestDistanceSquared = 0;

    for (final FocusNode node in scope.traversalDescendants) {
      final Offset center = node.rect.center; // Read exactly once per node.
      final int x = center.dx.round();
      final int y = center.dy.round();

      // Same filtering as findCandidates(): strictly in the requested
      // direction, and for left/right also on the same row as the origin.
      // These comparisons also exclude currentNode itself.
      switch (direction) {
        case TraversalDirection.up:
          if (y >= fromY) continue;
          break;
        case TraversalDirection.down:
          if (y <= fromY) continue;
          break;
        case TraversalDirection.left:
          if (x >= fromX || y != fromY) continue;
          break;
        case TraversalDirection.right:
          if (x <= fromX || y != fromY) continue;
          break;
      }

      final int dx = x - fromX;
      final int dy = y - fromY;
      // Squared distance: same ordering as the sqrt the original compared on.
      final int distanceSquared = dx * dx + dy * dy;

      if (best == null) {
        best = node;
        bestX = x;
        bestY = y;
        bestDistanceSquared = distanceSquared;
        continue;
      }

      // Same pairwise rule as findBestFocusNode(): prefer the nearest row (or
      // column), then the closest candidate within it.
      bool challengerWins;
      switch (direction) {
        case TraversalDirection.up:
          challengerWins = y > bestY;
          break;
        case TraversalDirection.down:
          challengerWins = y < bestY;
          break;
        case TraversalDirection.left:
          challengerWins = x > bestX;
          break;
        case TraversalDirection.right:
          challengerWins = x < bestX;
          break;
      }

      if (!challengerWins && y == bestY && distanceSquared < bestDistanceSquared) {
        challengerWins = true;
      }

      if (challengerWins) {
        best = node;
        bestX = x;
        bestY = y;
        bestDistanceSquared = distanceSquared;
      }
    }

    return best;
  }
}

class NodeSearcher {
  final TraversalDirection directionToSearch;

  NodeSearcher(this.directionToSearch);

  /// should be called first
  List<CandidateNode> findCandidates(List<FocusNode> nodes, FocusNode from) {
    List<FocusNode> copy = List.from(nodes, growable: true);

    switch (directionToSearch) {
      case TraversalDirection.up:
        copy.removeWhere((element) => element.isBelowOrEquals(from));
        break;
      case TraversalDirection.down:
        copy.removeWhere((element) => element.isAboveOrEquals(from));
        break;
      case TraversalDirection.right:
        copy.removeWhere((element) => element.isLeftToOrEquals(from) || !element.isOnTheSameRow(from));
        break;
      case TraversalDirection.left:
        copy.removeWhere((element) => element.isRightToOrEquals(from) || !element.isOnTheSameRow(from));
        break;
    }
    return toCandidateNodes(copy);
  }

  FocusNode findBestFocusNode(List<CandidateNode> nodes, FocusNode from) {
    List<FocusNode> candidates = toFocusNodes(nodes);

    return candidates.reduce((bestNode, challenger) {
      if (directionToSearch == TraversalDirection.down && challenger.isAbove(bestNode)) {
        return challenger;
      } else if (directionToSearch == TraversalDirection.up && challenger.isBelow(bestNode)) {
        return challenger;
      } else if (directionToSearch == TraversalDirection.left && challenger.isRightTo(bestNode)) {
        return challenger;
      } else if (directionToSearch == TraversalDirection.right && challenger.isLeftTo(bestNode)) {
        return challenger;
      }
      // compute the element which is the closest horizontally
      if (challenger.isOnTheSameRow(bestNode) && challenger.distance(from) < bestNode.distance(from)) {
        return challenger;
      }
      return bestNode;
    });
  }
}

/// An internal object to use the [NodeSearcher] class as expected
class CandidateNode {
  final FocusNode node;

  CandidateNode(this.node);
}

/// Some conversion utilities used internally
List<CandidateNode> toCandidateNodes(List<FocusNode> nodes) => nodes.map((e) => CandidateNode(e)).toList();

List<FocusNode> toFocusNodes(List<CandidateNode> nodes) => nodes.map((e) => e.node).toList();

/// A few extension methods to the [FocusNode] to be able to compare their
/// respective position easily.
extension Geometry on FocusNode {
  bool isBelow(FocusNode other) {
    return rect.center.dy.round() > other.rect.center.dy.round();
  }

  bool isBelowOrEquals(FocusNode other) {
    return rect.center.dy.round() >= other.rect.center.dy.round();
  }

  bool isRightTo(FocusNode other) {
    return rect.center.dx.round() > other.rect.center.dx.round();
  }

  bool isRightToOrEquals(FocusNode other) {
    return rect.center.dx.round() >= other.rect.center.dx.round();
  }

  bool isLeftTo(FocusNode other) {
    return rect.center.dx.round() < other.rect.center.dx.round();
  }

  bool isLeftToOrEquals(FocusNode other) {
    return rect.center.dx.round() <= other.rect.center.dx.round();
  }

  bool isAbove(FocusNode other) {
    return rect.center.dy.round() < other.rect.center.dy.round();
  }

  bool isAboveOrEquals(FocusNode other) {
    return rect.center.dy.round() <= other.rect.center.dy.round();
  }

  bool isOnTheSameRow(FocusNode other) {
    return rect.center.dy.round() == other.rect.center.dy.round();
  }

  double distance(FocusNode other) {
    return sqrt(pow(rect.center.dx.round() - other.rect.center.dx.round(), 2) +
        pow(rect.center.dy.round() - other.rect.center.dy.round(), 2));
  }
}
