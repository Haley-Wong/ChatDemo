//
//  ContactsViewController.m
//  ChatDemo
//
//  Created by Joker on 15/7/21.
//  Copyright (c) 2015年 Mac. All rights reserved.
//

#import "ContactsViewController.h"
#import "ChatViewController.h"
#import "JKXMPPTool.h"

@interface ContactsViewController ()

@property (nonatomic, retain) NSMutableArray    *contacts;

@end

@implementation ContactsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = RGBColor(234, 239, 245, 1);
    
    self.tableView.tableFooterView = [UIView new];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rosterChange) name:kXMPP_ROSTER_CHANGE object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)addFriendAction:(id)sender {
    
}


#pragma mark - notification event
- (void)rosterChange
{
    //从存储器中取出我得好友数组，更新数据源
    self.contacts = [NSMutableArray arrayWithArray:[JKXMPPTool sharedInstance].xmppRosterMemoryStorage.unsortedUsers];
    [self.tableView reloadData];
    
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    return self.contacts.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"contactCell" forIndexPath:indexPath];
    
    XMPPUserMemoryStorageObject *user = self.contacts[indexPath.row];
    UILabel *nameLabel = (UILabel *)[cell viewWithTag:1001];
    nameLabel.text = user.jid.user;
    
    UILabel *statusLabel = (UILabel *)[cell viewWithTag:1002];
    if ([user isOnline]) {
        statusLabel.text = @"[在线]";
        statusLabel.textColor = [UIColor blackColor];
        nameLabel.textColor = [UIColor blackColor];
    } else {
        statusLabel.text = @"[离线]";
        statusLabel.textColor = [UIColor grayColor];
        nameLabel.textColor = [UIColor grayColor];
    }
    
    return cell;
}

//tableView的select Row:delegate 会在prepare方法之后执行
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"addFriendSegue"]) {
        
    } else if ([segue.identifier isEqualToString:@"chatSegue"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        XMPPUserMemoryStorageObject *user = self.contacts[indexPath.row];
        ChatViewController *chatVC = segue.destinationViewController;
        chatVC.chatJID = user.jid;
    }
}

@end
