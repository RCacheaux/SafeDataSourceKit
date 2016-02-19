//: Playground - noun: a place where people can play

import UIKit
import XCPlayground


func - (lhs: Range<Int>, rhs: Int) -> Range<Int> {
  if lhs.endIndex == 0 {
    return Range(start: 0, end: 0)
  } else if lhs.startIndex >= lhs.endIndex - rhs {
    return Range(start: lhs.startIndex, end: lhs.startIndex)
  } else {
    return Range(start: lhs.startIndex, end: lhs.endIndex.advancedBy(-rhs))
  }
}

func + (lhs: Range<Int>, rhs: Int) -> Range<Int> {
  return Range(start: lhs.startIndex, end: lhs.endIndex.advancedBy(rhs))
}

func add(lhs: Range<Int>, rhs: Int) -> Range<Int> {
  return Range(start: lhs.startIndex, end: lhs.endIndex.advancedBy(rhs))
}

//func += (lhs: Range<Int>, rhs: Int) -> Range<Int> {
//  return Range(start: lhs.startIndex, end: lhs.endIndex.advancedBy(rhs))
//}



func >> (lhs: Range<Int>, rhs: Int) -> Range<Int> {
  return Range(start: lhs.startIndex.advancedBy(rhs), end: lhs.endIndex.advancedBy(rhs))
}

func << (lhs: Range<Int>, rhs: Int) -> Range<Int> {
  return Range(start: lhs.startIndex.advancedBy(-rhs), end: lhs.endIndex.advancedBy(-rhs))
}

func shiftAdd(lhs: Range<Int>, rhs: Int) -> Range<Int> {
  return Range(start: lhs.startIndex.advancedBy(rhs), end: lhs.endIndex.advancedBy(rhs))
}

func shiftRemove(lhs: Range<Int>, rhs: Int) -> Range<Int> {
  return Range(start: lhs.startIndex.advancedBy(-rhs), end: lhs.endIndex.advancedBy(-rhs))
}

var g = 0..<0
g = g - 1

var y = 0...10
let a = y.startIndex.advancedBy(1)
let b = y.endIndex.advancedBy(1)
let z = Range(start: a, end: b)

struct Color {
  let hue: CGFloat
  let saturation: CGFloat
  let brightness: CGFloat
}

extension UIColor {
  convenience init(color: Color) {
    self.init(hue: color.hue, saturation: color.saturation, brightness: color.brightness, alpha: 1)
  }
}

private enum DataChange<T> {
  // Section
  case AppendSection
  case AppendSections(Int) // Number of sections
  case InsertSection(Int) // Section Index
  case InsertSections(NSIndexSet)
  case DeleteSection(Int) // Section Index
  case DeleteSections(NSIndexSet)
  case DeleteLastSection
  case DeleteSectionsStartingAtIndex(Int)
  case MoveSection(Int, Int)
  // Item
  case AppendItem(T, Int) // Item, Section Index
  case AppendItems([T], Int) // Items, Section Index
  case InsertItem(T, NSIndexPath)
  case InsertItems([T], [NSIndexPath])
  case DeleteItem(NSIndexPath)
  case DeleteItems([NSIndexPath])
  case DeleteLastItem(Int) // Section Index
  case DeleteItemsStartingAtIndexPath(NSIndexPath) // Will delete all items from index path forward for section
  case MoveItem(NSIndexPath, NSIndexPath)
}


public class SafeDataSource<T>: NSObject, UICollectionViewDataSource {
  public typealias CellForItemAtIndexPath = (UICollectionView, T, NSIndexPath) -> UICollectionViewCell

  let collectionView: UICollectionView
  var dataSourceItems: [[T]] = [] // Only change this on main thread an coordinate it with batch insertion completion.
  var items: [[T]] = []
  private var pendingChanges: [DataChange<T>] = []

  let cellForItemAtIndexPath: CellForItemAtIndexPath

  let mutateDisplayQueue = SerialOperationQueue()
  let dataMutationDispatchQueue = dispatch_queue_create("com.rcach.safeDataSourceKit.dataMutation", DISPATCH_QUEUE_SERIAL)

  public convenience init(items: [[T]], collectionView: UICollectionView, cellForItemAtIndexPath: CellForItemAtIndexPath) {
    self.init(collectionView: collectionView, cellForItemAtIndexPath: cellForItemAtIndexPath)
    self.dataSourceItems = items
    self.items = items
  }


  public init(collectionView: UICollectionView, cellForItemAtIndexPath: CellForItemAtIndexPath) {
    self.collectionView = collectionView
    self.cellForItemAtIndexPath = cellForItemAtIndexPath
    super.init()
    self.collectionView.dataSource = self
  }

  private func dequeuPendingChangesAndOnComplete(onComplete: [DataChange<T>] -> Void) { // TODO: Think about taking in the queue to call the on complete closure.
    dispatch_async(dataMutationDispatchQueue) {
      let pendingChangesToDequeue = self.pendingChanges
      self.pendingChanges.removeAll(keepCapacity: true)
      onComplete(pendingChangesToDequeue)
    }
  }

  func addApplyOperationIfNeeded() {
    if let lastOperation = self.mutateDisplayQueue.operations.last {
      if lastOperation.executing {
        let applyChangeOp = ApplyDataSourceChangeOperation(safeDataSource: self, collectionView: self.collectionView)
        self.mutateDisplayQueue.addOperation(applyChangeOp)
      }
    } else {
      let applyChangeOp = ApplyDataSourceChangeOperation(safeDataSource: self, collectionView: self.collectionView)
      self.mutateDisplayQueue.addOperation(applyChangeOp)
    }
  }


  // External Interface
  public func appendItem(item: T) {
    dispatch_async(dataMutationDispatchQueue) {
      // Automatically creates section 0 if it does not exist already.
      if self.items.count == 0 {
        self.unsafeAppendSectionWithItem(item)
      } else {
//        self.unsafeAppendItem(item, toSection: 0) // TODO: Remove ObjC msg_send overhead

        let section = 0
        guard section < self.items.count else { return } // TODO: Add more of these validations
        let startingIndex = self.items[section].count
        self.pendingChanges.append(.InsertItem(item, NSIndexPath(forItem: startingIndex, inSection: section)))
        self.items[section].append(item)
        self.addApplyOperationIfNeeded()
      }
    }
  }

  public func appendItem(item: T, toSection section: Int) {
    dispatch_async(dataMutationDispatchQueue) {
      self.unsafeAppendItem(item, toSection: section)
    }
  }

  @nonobjc @inline(__always)
  func unsafeAppendItem(item: T, toSection section: Int) {
    guard section < self.items.count else { return } // TODO: Add more of these validations
    let startingIndex = self.items[section].count
    self.pendingChanges.append(.InsertItem(item, NSIndexPath(forItem: startingIndex, inSection: section)))
    self.items[section].append(item)
    self.addApplyOperationIfNeeded()
  }

  public func appendSectionWithItems(items: [T]) {
    dispatch_async(dataMutationDispatchQueue) {
      self.unsafeAppendSectionWithItems(items)
    }
  }

  @nonobjc @inline(__always)
  func unsafeAppendSectionWithItems(items: [T]) {
    let newSectionIndex = self.items.count // This must happen first.
    self.pendingChanges.append(.AppendSection)
    self.items.append([])
    let indexPaths = items.enumerate().map { (index, item) -> NSIndexPath in
      return NSIndexPath(forItem: index, inSection: newSectionIndex)
    }
    self.pendingChanges.append(.InsertItems(items, indexPaths))
    self.items[newSectionIndex] = items
    self.addApplyOperationIfNeeded()
  }

  @nonobjc @inline(__always)
  func unsafeAppendSectionWithItem(item: T) {
    let newSectionIndex = self.items.count // This must happen first.
    self.pendingChanges.append(.AppendSection)
    self.items.append([])
    let indexPath = NSIndexPath(forItem: 0, inSection: newSectionIndex)
    self.pendingChanges.append(.InsertItem(item, indexPath))
    self.items[newSectionIndex].append(item)
    self.addApplyOperationIfNeeded()
  }

  // Instead allow consumer to give you a closure that we call and provide current
  //   data state and they can use that state to apply mutations
  public func insertItemWithClosure(getInsertionIndexPath: ([[T]]) -> (item: T, indexPath: NSIndexPath)?) {
    dispatch_async(dataMutationDispatchQueue) {
      guard let insertion = getInsertionIndexPath(self.items) else { return }
      insertion.indexPath.item
      self.pendingChanges.append(.InsertItem(insertion.item, insertion.indexPath))
      self.items[insertion.indexPath.section].insert(insertion.item, atIndex: insertion.indexPath.item)
      self.addApplyOperationIfNeeded()
    }
  }

  public func deleteItemWithClosure(getDeletionIndexPath: ([[T]]) -> NSIndexPath?) {
    dispatch_async(dataMutationDispatchQueue) {
      self.items[0].count
      guard let indexPath = getDeletionIndexPath(self.items) else { return }
      self.pendingChanges.append(.DeleteItem(indexPath))
      self.items[indexPath.section].removeAtIndex(indexPath.item)
      self.addApplyOperationIfNeeded()
      self.items[0].count
    }
  }

  public func deleteLastItemInSection(sectionIndex: Int) {
    dispatch_async(dataMutationDispatchQueue) {
      if self.items[sectionIndex].count > 0 {
        self.items[sectionIndex].removeLast()
        self.pendingChanges.append(.DeleteLastItem(sectionIndex))
        self.addApplyOperationIfNeeded()
      }
    }
  }



  public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return dataSourceItems[section].count
  }

  public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
    let cell = cellForItemAtIndexPath(collectionView, dataSourceItems[indexPath.section][indexPath.row], indexPath)
    return cell
  }

  public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
    return dataSourceItems.count
  }

  // func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView

  // iOS 9+
  // func collectionView(collectionView: UICollectionView, canMoveItemAtIndexPath indexPath: NSIndexPath) -> Bool

  // iOS 9+
  // func collectionView(collectionView: UICollectionView, moveItemAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath)

}



class SerialOperationQueue: NSOperationQueue {

  override init() {
    super.init()
    maxConcurrentOperationCount = 1
  }

  override func addOperation(op: NSOperation) {
    if let lastOperation = self.operations.last {
      if !lastOperation.finished {
        op.addDependency(lastOperation)
      }
    }
    super.addOperation(op)
  }

}





public class AsyncOperation: NSOperation {
  private var _executing = false
  private var _finished = false

  override private(set) public var executing: Bool {
    get {
      return _executing
    }
    set {
      willChangeValueForKey("isExecuting")
      _executing = newValue
      didChangeValueForKey("isExecuting")
    }
  }

  override private(set) public var finished: Bool {
    get {
      return _finished
    }
    set {
      willChangeValueForKey("isFinished")
      _finished = newValue
      didChangeValueForKey("isFinished")
    }
  }

  override public var asynchronous: Bool {
    return true
  }

  override public func start() {
    if cancelled {
      finished = true
      return
    }

    executing = true
    autoreleasepool {
      run()
    }
  }

  func run() {
    preconditionFailure("AsyncOperation.run() abstract method must be overridden.")
  }

  func finishedExecutingOperation() {
    executing = false
    finished = true
  }
}




/*
switch change {
case .AppendSection:
  let x = 1
case .AppendSections(let numberOfSections): // Number of sections
  let x = 1
case .InsertSection(let sectionIndex): // Section Index
  let x = 1
case .InsertSections(let indexSet):
  let x = 1
case .DeleteSection(let sectionIndex): // Section Index
  let x = 1
case .DeleteSections(let indexSet):
  let x = 1
case .DeleteLastSection:
  let x = 1
case .DeleteSectionsStartingAtIndex(let sectionIndex):
  let x = 1
case .MoveSection(let fromSectionIndex, let toSectionIndex):
  // Item
  let x = 1
case .AppendItem(let item, let sectionIndex): // Item, Section Index
  let x = 1
case .AppendItems(let items, let sectionIndex): // Items, Section Index
  let x = 1
case .InsertItem(let item, let indexPath):
  let x = 1
case .InsertItems(let items, let indexPaths):
  let x = 1
case .DeleteItem(let indexPath):
  let x = 1
case .DeleteItems(let indexPaths):
  let x = 1
case .DeleteLastItem(let sectionIndex): // Section Index
  let x = 1
case .DeleteItemsStartingAtIndexPath(let indexPath): // Will delete all items from index path forward for section
  let x = 1
case .MoveItem(let fromIndexPath, let toIndexPath):
  let x = 1
}
*/



class ApplyDataSourceChangeOperation<T>: AsyncOperation {
  let safeDataSource: SafeDataSource<T>
  let collectionView: UICollectionView

  init(safeDataSource: SafeDataSource<T>, collectionView: UICollectionView) {
    self.safeDataSource = safeDataSource
    self.collectionView = collectionView
    super.init()
  }


  override func run() {
    safeDataSource.dequeuPendingChangesAndOnComplete { changes in

      dispatch_async(dispatch_get_main_queue()) {
        // TODO: Can make this logic more efficient: Have to process deletions first because batch 
        //   updates will also apply deletions first so, if we haven't added the item we want to delete yet,
        //   the batch insertion will fail

        // Got changes, now head on over to collection view
        // We first apply all additions and then on complete we apply deletions and on complete of deletions we mark operation complete


        // TODO: Do all this math in a concurrent queue and only get on main queue once set of changes are calculated

        // Range of existing items in data source array before any changes applied in this op


        let preDeleteSectionStartingRanges = self.safeDataSource.dataSourceItems.enumerate().map { index, items in
          return 0..<self.safeDataSource.dataSourceItems[index].count
        }

        var sectionAdditions: [Int:Range<Int>] = [:]

        var sectionInsertions = self.safeDataSource.dataSourceItems.map { _ in
          return Set<NSIndexPath>()
        }
        var sectionDeletions = self.safeDataSource.dataSourceItems.map { _ in
          return Set<NSIndexPath>()
        }


        for change in changes {
          if case .DeleteItem(let midPointInTimeIndexPath) = change {
            // C:
            if preDeleteSectionStartingRanges[midPointInTimeIndexPath.section] ~= midPointInTimeIndexPath.item { // Deleting from existing items
              // This gets complicated, we need to offset any insertions into existing items after this index we are deleting
              sectionDeletions[midPointInTimeIndexPath.section].insert(midPointInTimeIndexPath)
            }
            // :C
          } else if case .DeleteItems(let midPointInTimeIndexPaths) = change {
            for indexPath in midPointInTimeIndexPaths {
              // C:
              if preDeleteSectionStartingRanges[indexPath.section] ~= indexPath.item { // Deleting from existing items
                // This gets complicated, we need to offset any insertions into existing items after this index we are deleting
                sectionDeletions[indexPath.section].insert(indexPath)
              }
              // :C
            }
          }
        }

        let postDeleteSectionStartingRanges = self.safeDataSource.dataSourceItems.enumerate().map { sectionIndex, items in
          return 0..<(self.safeDataSource.dataSourceItems[sectionIndex].count - sectionDeletions[sectionIndex].count)
        }


        var onGoingExistingDeletes: [[NSIndexPath]] = self.safeDataSource.dataSourceItems.map { _ in
          return []
        }

        for change in changes {
          switch change {
          case .AppendSection:
            let x = 1
          case .AppendSections(let numberOfSections): // Number of sections
            let x = 1
          case .InsertSection(let sectionIndex): // Section Index
            let x = 1
          case .InsertSections(let indexSet):
            let x = 1
          case .DeleteSection(let sectionIndex): // Section Index
            let x = 1
          case .DeleteSections(let indexSet):
            let x = 1
          case .DeleteLastSection:
            let x = 1
          case .DeleteSectionsStartingAtIndex(let sectionIndex):
            let x = 1
          case .MoveSection(let fromSectionIndex, let toSectionIndex):
            let x = 1
          case .AppendItem(_, let sectionIndex): // Item, Section Index
            if sectionAdditions[sectionIndex] == nil {
              let startingRange = postDeleteSectionStartingRanges[sectionIndex]
              sectionAdditions[sectionIndex] = startingRange.endIndex..<startingRange.endIndex
            }
            if let sectionAdditionsForSection = sectionAdditions[sectionIndex] {
              sectionAdditions[sectionIndex] = sectionAdditionsForSection + 1
            }
          case .AppendItems(let items, let sectionIndex): // Items, Section Index
            if sectionAdditions[sectionIndex] == nil {
              let startingRange = postDeleteSectionStartingRanges[sectionIndex]
              sectionAdditions[sectionIndex] = startingRange.endIndex..<startingRange.endIndex
            }
            if let sectionAdditionsForSection = sectionAdditions[sectionIndex] {
              sectionAdditions[sectionIndex] = sectionAdditionsForSection + items.count
            }
          case .InsertItem(_, let indexPath):
            // TODO: What if this is an insertion into a new section?
            // A:
            if preDeleteSectionStartingRanges[indexPath.section] ~= (indexPath.item + onGoingExistingDeletes[indexPath.section].count) { // Inserting into existing items
              sectionInsertions[indexPath.section].insert(indexPath)
              if let sectionAdditionsForSection = sectionAdditions[indexPath.section] {
                sectionAdditions[indexPath.section] = sectionAdditionsForSection >> 1
              }
            } else { // NOT inserting into existing items
              if sectionAdditions[indexPath.section] == nil {
                let startingRange = postDeleteSectionStartingRanges[indexPath.section]
                sectionAdditions[indexPath.section] = startingRange.endIndex..<startingRange.endIndex
              }
              if let sectionAdditionsForSection = sectionAdditions[indexPath.section] {
                sectionAdditions[indexPath.section] = sectionAdditionsForSection + 1
              }
            }
            // :A

          case .InsertItems(_, let indexPaths):
            for indexPath in indexPaths {
              // A:
              if preDeleteSectionStartingRanges[indexPath.section] ~= (indexPath.item + onGoingExistingDeletes[indexPath.section].count) { // Inserting into existing items
                sectionInsertions[indexPath.section].insert(indexPath)
                if let sectionAdditionsForSection = sectionAdditions[indexPath.section] {
                  sectionAdditions[indexPath.section] = sectionAdditionsForSection >> 1
                }
              } else { // NOT inserting into existing items
                if sectionAdditions[indexPath.section] == nil {
                  let startingRange = postDeleteSectionStartingRanges[indexPath.section]
                  sectionAdditions[indexPath.section] = startingRange.endIndex..<startingRange.endIndex
                }
                if let sectionAdditionsForSection = sectionAdditions[indexPath.section] {
                  sectionAdditions[indexPath.section] = sectionAdditionsForSection + 1
                }
              }
              // :A

            }

          case .DeleteItem(let indexPath):
            // B:
            // This accounts for the fact that the index path given to us is in the context of an array with potentially deleted items.
            if preDeleteSectionStartingRanges[indexPath.section] ~= (indexPath.item + onGoingExistingDeletes[indexPath.section].count)   { // Deleting from existing items
              // Do nothing this deletion has already been accounted for, excpet for keeping track
              onGoingExistingDeletes[indexPath.section].append(indexPath) // TODO: will something reference this index path later if so be careful about index that should be shifted!


            } else { // NOT deleting from existing items, no deleting from datasource, items never made it to collection view no need to add these items just to delete them
              if let sectionAdditionsForSection = sectionAdditions[indexPath.section] {
                sectionAdditions[indexPath.section] = sectionAdditionsForSection - 1 // TODO: Remove addition range if range becomes 0..<0
              } else {
                // This should never occur, this means a delete command was given for an item that hasn't been added yet. We are iterating in the changlist order.
                assertionFailure("Encountered an addition deletion for an item that has not been added before in the changelist order.")
              }
            } // :B

          case .DeleteItems(let indexPaths):
            for indexPath in indexPaths {
              // B:
              // This accounts for the fact that the index path given to us is in the context of an array with potentially deleted items.
              if preDeleteSectionStartingRanges[indexPath.section] ~= (indexPath.item + onGoingExistingDeletes[indexPath.section].count)   { // Deleting from existing items
                // Do nothing this deletion has already been accounted for, excpet for keeping track
                onGoingExistingDeletes[indexPath.section].append(indexPath)

              } else { // NOT deleting from existing items, no deleting from datasource, items never made it to collection view no need to add these items just to delete them
                if let sectionAdditionsForSection = sectionAdditions[indexPath.section] {
                  sectionAdditions[indexPath.section] = sectionAdditionsForSection - 1 // TODO: Remove addition range if range becomes 0..<0
                } else {
                  // This should never occur, this means a delete command was given for an item that hasn't been added yet. We are iterating in the changlist order.
                  assertionFailure("Encountered an addition deletion for an item that has not been added before in the changelist order.")
                }
              } // :B
            }
          case .DeleteLastItem: // Section Index

            assertionFailure("Delete Last Item in Section not implemented yet.")


            /*
            if let sectionAdditionsForSection = sectionAdditions[sectionIndex] { // There are additions, just remove from there
              let x = 1
              sectionAdditions[sectionIndex]?.startIndex
              sectionAdditions[sectionIndex]?.endIndex
              sectionAdditions[sectionIndex] = sectionAdditionsForSection - 1
              if sectionAdditions[sectionIndex]!.startIndex == sectionAdditions[sectionIndex]!.endIndex {
                sectionAdditions[sectionIndex] = nil
              }
            } else if self.safeDataSource.dataSourceItems[sectionIndex].count > 0 { // If there are existing items in this section, remove the last one
              let x = 1
              // Look for deletions at the end of the existing items in this section, and a
              let candidate = NSIndexPath(forItem: self.safeDataSource.dataSourceItems[sectionIndex].count - 1, inSection: sectionIndex)
              if sectionDeletions[sectionIndex].count == 0 {
                sectionDeletions[sectionIndex].insert(candidate)
              } else {
                var fromEnd = 1
                var foundDelete = false
                while !foundDelete {
                  let candidate = NSIndexPath(forItem: self.safeDataSource.dataSourceItems[sectionIndex].count - fromEnd, inSection: sectionIndex)
                  if !sectionDeletions[sectionIndex].contains(candidate) {
                    if sectionInsertions[sectionIndex].contains(candidate) {
                      sectionInsertions[sectionIndex].remove(candidate)
                    }

                    sectionDeletions[sectionIndex].insert(candidate)
                    sectionDeletions[sectionIndex].count // TODO: If this results in a deletion of something that is inside the insertion set of index paths, this logic should remove that index path from the insertions index path
                    foundDelete = true
                  } else {
                    let x = 1
                    fromEnd += 1
                  }
                }
              }

            } else {
              print(":-/")
            }
            */

          case .DeleteItemsStartingAtIndexPath: // Will delete all items from index path forward for section
            assertionFailure("Delete items starting at index path not implemented yet.")

          case .MoveItem(let fromIndexPath, let toIndexPath):
            // TODO: Handle if move is for item that is to be deleted.


            // >>>> TODO!!!!!! - the + shift should only occur for deletions with item index less than this guys
            let fromIndexPathInExistingItemRange = preDeleteSectionStartingRanges[fromIndexPath.section] ~= (fro mIndexPath.item + onGoingExistingDeletes[fromIndexPath.section].count)
            let toIndexPathInExistingItemRange = preDeleteSectionStartingRanges[toIndexPath.section] ~= (toIndexPath.item + onGoingExistingDeletes[toIndexPath.section].count)
            if fromIndexPathInExistingItemRange && toIndexPathInExistingItemRange { // TODO: Test for if existing with pre delete data structure and shift index paths based on ongoing existingDeletes.
              // is the move within existing?
              // then it's a move operation - Need to figure out what the real from index path and to index path are
              // is there a delete...
              // is the move going to affect any pending changes within existing items?


              // The move is within the postDelete existing items, just need to make a move op with theses index paths


              // Take into account any deletions within the existing items and shift the index paths accordingly

            } else if !toIndexPathInExistingItemRange && !toIndexPathInExistingItemRange {
              // is the move within additions?
              // just need to change the index paths where this will initially get inserted, no move necessary


            } else {
              // is the move across additions and existing
              // I THINK this is just a move operation, need to verify


            }







            let x = 1
          }
        }



        // TODO: Do this with higher order functions
        var _newIndexPathsToAdd: [NSIndexPath] = []
        for (sectionIndex, sa) in sectionAdditions {
          sa
          for a in sa {
            _newIndexPathsToAdd.append(NSIndexPath(forItem: a, inSection: sectionIndex))
          }
        }

        for insertions in sectionInsertions {
          for indexPath in insertions {
            _newIndexPathsToAdd.append(indexPath)
          }
        }

        var _newIndexPathsToDelete: [NSIndexPath] = []
        for deletions in sectionDeletions {
          for indexPath in deletions {
            print("Will Delete: \(indexPath.section):\(indexPath.item)")
            _newIndexPathsToDelete.append(indexPath)
          }
        }



        self.collectionView.performBatchUpdates({
          // Perform changes
          var indexPathsToAdd: [NSIndexPath] = []
          for change in changes {
            if case .AppendSection = change {
              let newSectionIndex = self.safeDataSource.dataSourceItems.count
              self.safeDataSource.dataSourceItems.append([])
              self.collectionView.insertSections(NSIndexSet(index: newSectionIndex))
            } else if case .InsertItem(let item, let indexPath) = change {
              print(indexPath.item)
              indexPathsToAdd.append(indexPath)
              // TODO: Validate that item's index path matches index in array below:
              self.safeDataSource.dataSourceItems[indexPath.section].insert(item, atIndex: indexPath.item)
            } else if case .InsertItems(let items, let newIndexPaths) = change {
              indexPathsToAdd += newIndexPaths
              for (index, item) in items.enumerate() {
                let indexPath = newIndexPaths[index]
                self.safeDataSource.dataSourceItems[indexPath.section].insert(item, atIndex: indexPath.item)
              }
           } else if case .DeleteItem(let indexPath) = change {

              self.safeDataSource.dataSourceItems[indexPath.section].removeAtIndex(indexPath.item)

            } else if case .DeleteLastItem(let sectionIndex) = change {
              if self.safeDataSource.dataSourceItems[sectionIndex].count > 0 {
                self.safeDataSource.dataSourceItems[sectionIndex].removeLast()
              }
            }
          }


          print("-")
          if _newIndexPathsToAdd.count > 0 {
            self.collectionView.insertItemsAtIndexPaths(_newIndexPathsToAdd)
          }
          if _newIndexPathsToDelete.count > 0 {
            self.collectionView.deleteItemsAtIndexPaths(_newIndexPathsToDelete)
          }
          // Plus reload operations
          // Plus move operations


        }) { completed in
          self.finishedExecutingOperation()
        }
      }
    }
  }




  func itemBatchStartingIndexPath(deletionsUpToThisPoint deletionsUpToThisPoint: [[NSIndexPath]], givenIndexPath: NSIndexPath) -> NSIndexPath {
    var offsetCount = 0 // TODO: Use fancy higher order funcs if possible
    let deletions = deletionsUpToThisPoint[givenIndexPath.section]
    for deletion in deletions {
      if deletion.item < givenIndexPath.item { // TODO: Think more about whether this should be <=
        offsetCount += 1
      }
    }
    return NSIndexPath(forRow: givenIndexPath.item + offsetCount, inSection: givenIndexPath.section)
  }
}






let cellForItem = { (collectionView: UICollectionView, item: Color, indexPath: NSIndexPath) -> UICollectionViewCell in
  let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath)
  cell.backgroundColor = UIColor(color: item)
  return cell
}


class InteractionHandler: NSObject {
  let safeDataSource: SafeDataSource<Color>

  init(safeDataSource: SafeDataSource<Color>) {
    self.safeDataSource = safeDataSource
    super.init()
  }

  func handleTap() {
    safeDataSource.appendItem(Color(hue: 0.5, saturation: 1.0, brightness: 0.8))
  }

}

let flowLayout = UICollectionViewFlowLayout()
flowLayout.itemSize = CGSizeMake(10, 10)
let collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: flowLayout)
let safeDataSource = SafeDataSource<Color>(items: [[]], collectionView: collectionView, cellForItemAtIndexPath: cellForItem)
collectionView.frame = CGRectMake(0, 0, 500, 1000)
collectionView.registerClass(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")

XCPlaygroundPage.currentPage.liveView = collectionView
XCPlaygroundPage.currentPage.needsIndefiniteExecution = true

let interactionHandler = InteractionHandler(safeDataSource: safeDataSource)
let tgr = UITapGestureRecognizer(target: interactionHandler, action: "handleTap")
collectionView.addGestureRecognizer(tgr)

dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
  for _ in (0...1000) {
    interactionHandler.handleTap()
  }

  interactionHandler.safeDataSource.insertItemWithClosure { colors in
    print("Insert item")
    if colors.count > 0 {
      if colors[0].count > 10 {
        colors[0].count - 8
        let indexPath = NSIndexPath(forItem: 4, inSection: 0)
        indexPath.item
        return (Color(hue: 0.1, saturation: 1.0, brightness: 0.9), indexPath)
      }
    }
    return nil
  }

  for _ in (0...2) { // TODO: Try (0...1) and this will crash, support multiple consecutive deletes
    interactionHandler.safeDataSource.deleteItemWithClosure { colors in
      print("Delete item: loop")
      if colors.count > 0 {
        if colors[0].count > 10 {
          return NSIndexPath(forItem: colors[0].count - 2, inSection: 0)
        }
      }
      return nil
    }
  }

  interactionHandler.safeDataSource.deleteItemWithClosure { colors in
    print("Delete item: last")
    return NSIndexPath(forItem: 0, inSection: 0)
  }

//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0)
//  interactionHandler.safeDataSource.deleteLastItemInSection(0) // TODO: uncomment and support this use case

}











