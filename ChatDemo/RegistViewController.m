//
//  RegistViewController.m
//  ChatDemo
//
//  Created by Joker on 15/7/19.
//  Copyright (c) 2015年 Mac. All rights reserved.
//

#import "RegistViewController.h"
#import "JKXMPPTool.h"

@interface RegistViewController ()

@property (weak, nonatomic) IBOutlet UITextField *usernameField;
@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet UITextField *confirmField;

@end

@implementation RegistViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
//    self.view.backgroundColor = [UIColor lightGrayColor];
    self.tableView.tableFooterView = [UIView new];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(registResult:) name:kREGIST_RESULT object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)registAction:(id)sender {
    NSString *username = _usernameField.text;
    NSString *password = _passwordField.text;
    NSString *confirm = _confirmField.text;
    
    NSString *message = nil;
    if (username.length <= 0) {
        message = @"用户名未填写";
    } else if (password.length <= 0) {
        message = @"密码未填写";
    } else if (confirm.length <= 0) {
        message = @"确认密码未填写";
    }
    
    if (message.length > 0) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:@"我知道了" otherButtonTitles:nil];
        [alertView show];
    } else if (![password isEqualToString:confirm]) {
        message = @"密码与确认密码不一致";
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:@"我知道了" otherButtonTitles:nil];
        [alertView show];
    } else {
        [[JKXMPPTool sharedInstance] registerWithJID:[XMPPJID jidWithUser:username domain:kXMPP_DOMAIN resource:kXMPP_RESOURCE] andPassword:password];
    }
}
- (IBAction)cancelClick:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - notification event
- (void)registResult:(NSNotification *)notification
{
    NSNumber *number = notification.object;
    NSString *message = @"";
    if (number.boolValue) {
        message = @"注册成功";
    } else {
        message = @"注册失败";
    }
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:@"我知道了" otherButtonTitles:nil];
    [alertView show];
}

@end
