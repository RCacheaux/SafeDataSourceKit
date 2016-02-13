//  Copyright © 2016 René Cacheaux. All rights reserved.

import Foundation

public class SerialUIOperationQueue: NSOperationQueue {

  public override init() {
    super.init()
    maxConcurrentOperationCount = 1
    underlyingQueue = dispatch_get_main_queue()
  }

  public override func addOperation(op: NSOperation) {
    if let lastOperation = self.operations.last {
      if !lastOperation.finished {
        op.addDependency(lastOperation)
      }
    }
    super.addOperation(op)
  }
  
}
