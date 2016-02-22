//: Playground - noun: a place where people can play

import UIKit

var str = "Hello, playground"


var existingItemDeletionAdjustedIndexPaths: [Set<NSIndexPath>] = []
var deletionIndexPathAdjustmentTable: [Int] = []



func adjustedDeletionItemIndex(pointInTimeItemIndex: Int, adjustmentTable: [Int]) -> Int {
  var adjustment = 0
  for adj in adjustmentTable {
    if pointInTimeItemIndex >= adj {
      adjustment += 1
    }
  }
  return pointInTimeItemIndex + adjustment
}

func adjustTableIfNecessaryWithPointInTimeDeletionItemIndex(pointInTimeItemIndex: Int, inout adjustmentTable: [Int]) {
  // If deleting item above previous deletes, need to offset the below adjustments -1
  for (i, adj) in adjustmentTable.enumerate() {
    if adj > pointInTimeItemIndex {
      adjustmentTable[i] = adjustmentTable[i] - 1
    }
  }
  // Add this point in time index to adj table
  adjustmentTable.append(pointInTimeItemIndex)
}

var data: [Int] = {
  return (0..<10).map { i in
    return i
  }
}()

var itemsToDelete: [Int] = []

func deleteItemAtIndex(index: Int) {
  let adjIndex = adjustedDeletionItemIndex(index, adjustmentTable: deletionIndexPathAdjustmentTable)
  adjustTableIfNecessaryWithPointInTimeDeletionItemIndex(index, adjustmentTable: &deletionIndexPathAdjustmentTable)
  itemsToDelete.append(adjIndex)
}

deleteItemAtIndex(8)
deleteItemAtIndex(2)
deleteItemAtIndex(3)
deleteItemAtIndex(1)
deleteItemAtIndex(1)
deleteItemAtIndex(3)
deleteItemAtIndex(3)
deleteItemAtIndex(1)
deleteItemAtIndex(1)

itemsToDelete
deletionIndexPathAdjustmentTable