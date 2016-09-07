//
//  SettingViewController.m
//  ChatDemo
//
//  Created by Haley on 16/3/3.
//  Copyright © 2016年 Mac. All rights reserved.
//

#import "SettingViewController.h"
#import "JKXMPPTool.h"

@interface SettingViewController ()

@property (strong, nonatomic)   NSArray            *settingTitles;  /**< 设置页标题 */

@end

@implementation SettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 60)];
    UIButton *exitBtn = [[UIButton alloc] initWithFrame:CGRectMake((CGRectGetWidth(self.view.frame) - 300) * 0.5, 10, 300, 40)];
    exitBtn.backgroundColor = [UIColor orangeColor];
    [exitBtn setTitle:@"退出登录" forState:UIControlStateNormal];
    [exitBtn addTarget:self action:@selector(logoutClick:) forControlEvents:UIControlEventTouchUpInside];
    [footerView addSubview:exitBtn];
    
    self.tableView.tableFooterView = footerView;
}

- (IBAction)logoutClick:(id)sender
{
    [[JKXMPPTool sharedInstance] logout];
    
    [self.tabBarController dismissViewControllerAnimated:true completion:nil];
}


@end
