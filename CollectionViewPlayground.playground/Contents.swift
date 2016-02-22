//: Playground - noun: a place where people can play

import UIKit
import XCPlayground

XCPlaygroundPage.currentPage.needsIndefiniteExecution = true


class DataSource: NSObject, UICollectionViewDataSource {
  var data: [Int] = []

  override init() {
    for i in 0..<10 {
      data.append(i)
    }
    super.init()
  }

  func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return data.count
  }

  func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath)
    cell.backgroundColor = UIColor.darkGrayColor()
    print(indexPath.item)
    return cell
  }
}

func delayOnMainQueue(delay:Double, closure:()->()) {
  dispatch_after(
    dispatch_time(
      DISPATCH_TIME_NOW,
      Int64(delay * Double(NSEC_PER_SEC))
    ),
    dispatch_get_main_queue(), closure)
}



let flowLayout = UICollectionViewFlowLayout()
flowLayout.itemSize = CGSize(width: 40, height: 40)
let collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: flowLayout)
collectionView.frame = CGRectMake(0, 0, 400, 800)
XCPlaygroundPage.currentPage.liveView = collectionView

collectionView.registerClass(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
let dataSource = DataSource()
collectionView.dataSource = dataSource



delayOnMainQueue(5) {
  dataSource.data.removeFirst()
  dataSource.data.append(10)

  collectionView.performBatchUpdates({
    collectionView.deleteItemsAtIndexPaths([NSIndexPath(forItem: 0, inSection: 0)])
    collectionView.insertItemsAtIndexPaths([NSIndexPath(forItem: 9, inSection: 0)])

    }, completion: { completed in

  })



}

