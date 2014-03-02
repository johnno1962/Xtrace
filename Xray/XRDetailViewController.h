//
//  XRDetailViewController.h
//  Xray
//
//  Created by John Holdsworth on 28/02/2014.
//  Copyright (c) 2014 John Holdsworth. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface XRDetailViewController : UIViewController

@property (strong, nonatomic) id detailItem;

@property (assign, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
