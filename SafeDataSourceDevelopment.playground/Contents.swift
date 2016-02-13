//: Playground - noun: a place where people can play

import UIKit
import XCPlayground






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


enum DataChange<T> {
  case Insert(T, NSIndexPath)
  case Delete(Int)
}



//class SafeCollectionViewDataSource<T> {
//  func collectionView(collectionView: UICollectionView, cellForItem item: T, atIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
//    preconditionFailure("collectionView:cellForItem:atIndexPath: is abstract and must be overridden.")
//  }
//}


protocol SafeCollectionViewDataSource {
  func collectionView<T>(collectionView: UICollectionView, cellForItem item: T, atIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
}


class SafeDataSource<T>: NSObject, UICollectionViewDataSource {
  let cellProvider: SafeCollectionViewDataSource
  let collectionView: UICollectionView
  var dataSourceItems: [[T]] = [] // Only change this on main thread an coordinate it with batch insertion completion.
  var items: [[T]] = []
  var pendingChanges: [DataChange<T>] = []

  let mutateDisplayQueue = SerialOperationQueue()
  let dataMutationDispatchQueue = dispatch_queue_create("com.rcach.safeDataSourceKit.dataMutation", DISPATCH_QUEUE_SERIAL)

  init(collectionView: UICollectionView, cellProvider: SafeCollectionViewDataSource) {
    self.collectionView = collectionView
    self.cellProvider = cellProvider
    super.init()
  }

  func dequeuPendingChangesAndOnComplete(onComplete: [DataChange<T>] -> Void) { // TODO: Think about taking in the queue to call the on complete closure.
    dispatch_async(dataMutationDispatchQueue) {
      let pendingChangesToDequeue = self.pendingChanges
      self.pendingChanges.removeAll(keepCapacity: true)
      onComplete(pendingChangesToDequeue)
    }
  }


  // External Interface
  func appendItem(item: T) {
    dispatch_async(dataMutationDispatchQueue) {
      if self.items.count == 0 {
        self.items.append([])
      }
      self.pendingChanges.append(DataChange.Insert(item, NSIndexPath(forItem: self.items[0].count, inSection: 0))) // This must happen before items array is mutated
      self.items[0].append(item)
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
  }

  // Instead allow consumer to give you a closure that we call and provide current 
  //   data state and they can use that state to apply mutations
  func insertItem(item: T, atIndex: Int) {
    dispatch_async(dataMutationDispatchQueue) {

    }
  }

  func removeItemAtIndex(index: Int) {
    dispatch_async(dataMutationDispatchQueue) {

    }
  }



  func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return dataSourceItems[section].count
  }

  func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
    return cellProvider.collectionView(collectionView, cellForItem: items[indexPath.section][indexPath.row], atIndexPath: indexPath)
  }

  func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
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



class ApplyDataSourceChangeOperation<T>: AsyncOperation {
  let safeDataSource: SafeDataSource<T>
  let collectionView: UICollectionView
//  let workingQueue = dispatch_queue_create("com.rcach.safeDataSourceKit.applyDataSourceChangeOperation", DISPATCH_QUEUE_SERIAL)

  init(safeDataSource: SafeDataSource<T>, collectionView: UICollectionView) {
    self.safeDataSource = safeDataSource
    self.collectionView = collectionView
    super.init()
  }

  override func run() {

    safeDataSource.dequeuPendingChangesAndOnComplete { changes in
      dispatch_async(dispatch_get_main_queue()) {
        // Got changes, now head on over to collection view
        self.collectionView.performBatchUpdates({
          if self.collectionView.numberOfSections() == 0 {
            self.safeDataSource.dataSourceItems.append([])
            self.collectionView.insertSections(NSIndexSet(index: 0))
          }


          // Perform changes
          var indexPaths: [NSIndexPath] = []
          for change in changes {
            if case .Insert(let item, let indexPath) = change {
              indexPaths.append(indexPath)
              // TODO: Validate that item's index path matches index in array below:
              self.safeDataSource.dataSourceItems[0].append(item)
            }
          }

          indexPaths
          self.collectionView.insertItemsAtIndexPaths(indexPaths)
//          self.collectionView.deleteItemsAtIndexPaths([])
          // Plus reload operations
          // Plus move operations

        }) { completed in
          self.finishedExecutingOperation()
        }
      }
    }

  }


}

class ColorCellProvider: NSObject, SafeCollectionViewDataSource {

  func collectionView<T>(collectionView: UICollectionView, cellForItem item: T, atIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath)
    if let color = item as? Color {
      cell.backgroundColor = UIColor(color: color)
    }
    return cell
  }

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

let cellProvider = ColorCellProvider()

let flowLayout = UICollectionViewFlowLayout()
flowLayout.itemSize = CGSizeMake(10, 10)
let collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: flowLayout)
let safeDataSource = SafeDataSource<Color>(collectionView: collectionView, cellProvider: cellProvider)
collectionView.dataSource = safeDataSource
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
}








