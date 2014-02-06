//
//  SettingsViewController.m
//  SonicSlingShot
//
//  Created by Azim Pradhan on 1/26/14.
//  Copyright (c) 2014 Ge Wang. All rights reserved.
//

#import "SettingsViewController.h"
#import "renderer.h"
#import "ShotGlobals.h"

@interface SettingsViewController ()
@property (weak, nonatomic) IBOutlet UISlider *damping;
@property (weak, nonatomic) IBOutlet UISlider *gravity;

@end

@implementation SettingsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.gravity setValue:ShotGlobals::gravity];
    [self.damping setValue:ShotGlobals::damping];

	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)dampingChanged:(id)sender {
    ShotGlobals::damping = self.damping.value;
}
- (IBAction)gravityChanged:(id)sender {
    ShotGlobals::gravity = self.gravity.value;
}

@end
