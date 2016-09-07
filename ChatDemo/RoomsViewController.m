//
//  RoomsViewController.m
//  ChatDemo
//
//  Created by Haley on 16/7/22.
//  Copyright © 2016年 Mac. All rights reserved.
//

#import "RoomsViewController.h"

#import "XMPPRoom.h"
#import "XMPPRoomHybridStorage.h"
#import "XMPPRoomMemoryStorage.h"
#import "JKXMPPTool.h"
#import "XMPPRoom.h"

@interface RoomsViewController ()

@property (nonatomic, retain) NSMutableArray    *rooms;

@end

@implementation RoomsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = RGBColor(234, 239, 245, 1);
    
    self.rooms = [NSMutableArray array];
    
    UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(freshClick)];
    self.navigationItem.leftBarButtonItem = leftItem;
    
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addClick)];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    self.tableView.tableFooterView = [UIView new];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getRoomsResult:) name:kXMPP_GET_GROUPS object:nil];
    
    [self loadRooms];
}

- (void)addClick
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *currentTime = [formatter stringFromDate:[NSDate date]];
    NSString *roomId = [NSString stringWithFormat:@"%@@%@.%@",currentTime,kXMPP_SUBDOMAIN,kXMPP_DOMAIN];
    
    XMPPJID *roomJID = [XMPPJID jidWithString:roomId];

    // 如果不需要使用自带的CoreData存储，则可以使用这个。
//    XMPPRoomMemoryStorage *xmppRoomStorage = [[XMPPRoomMemoryStorage alloc] init];
    
    // 如果使用自带的CoreData存储，可以自己创建一个继承自XMPPCoreDataStorage，并且实现了XMPPRoomStorage协议的类
    // XMPPRoomHybridStorage在类注释中，写了这只是一个实现的示例，不太建议直接使用这个。
    XMPPRoomHybridStorage *xmppRoomStorage = [XMPPRoomHybridStorage sharedInstance];

    XMPPRoom *xmppRoom = [[XMPPRoom alloc] initWithRoomStorage:xmppRoomStorage jid:roomJID dispatchQueue:dispatch_get_main_queue()];

    [xmppRoom activate:[JKXMPPTool sharedInstance].xmppStream];
    [xmppRoom addDelegate:self delegateQueue:dispatch_get_main_queue()];

    [xmppRoom joinRoomUsingNickname:@"haley" history:nil password:nil];
}

- (void)freshClick
{
    [self.rooms removeAllObjects];
    [self loadRooms];
}

- (void)loadRooms
{
    NSXMLElement *queryElement= [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#items"];
    NSXMLElement *iqElement = [NSXMLElement elementWithName:@"iq"];
    [iqElement addAttributeWithName:@"type" stringValue:@"get"];
    [iqElement addAttributeWithName:@"from" stringValue:[JKXMPPTool sharedInstance].xmppStream.myJID.bare];
    NSString *service = [NSString stringWithFormat:@"%@.%@",kXMPP_SUBDOMAIN,kXMPP_DOMAIN];
    [iqElement addAttributeWithName:@"to" stringValue:service];
    [iqElement addAttributeWithName:@"id" stringValue:@"getMyRooms"];
    [iqElement addChild:queryElement];
    [[JKXMPPTool sharedInstance].xmppStream sendElement:iqElement];
}

#pragma mark - NSNotification Event 
- (void)getRoomsResult:(NSNotification *)notification
{
    NSArray *array = [notification object];
    
    NSLog(@"%@,群组列表：%@",[NSThread currentThread],array);
    
    [self.rooms addObjectsFromArray:array];
    [self.tableView reloadData];
}

#pragma mark -  XMPPRoomDelegate
- (void)xmppRoomDidCreate:(XMPPRoom *)sender
{
    NSLog(@"房间创建成功");
}

- (void)xmppRoomDidJoin:(XMPPRoom *)sender
{
    NSLog(@"加入房间成功");
    
    [self configNewRoom:sender];
    
    NSString *message = [NSString stringWithFormat:@"群<%@>已创建完成",sender.roomJID.user];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"提示" message:message delegate:nil cancelButtonTitle:@"取消" otherButtonTitles:nil, nil];
        [alertView show];
    });
    
//    [sender fetchConfigurationForm];
//    [sender fetchBanList];
//    [sender fetchMembersList];
//    [sender fetchModeratorsList];
}

- (void)configNewRoom:(XMPPRoom *)xmppRoom
{
    NSXMLElement *x = [NSXMLElement elementWithName:@"x"xmlns:@"jabber:x:data"];
    NSXMLElement *p = [NSXMLElement elementWithName:@"field" ];
    [p addAttributeWithName:@"var"stringValue:@"muc#roomconfig_persistentroom"];//永久房间
    [p addChild:[NSXMLElement elementWithName:@"value"stringValue:@"1"]];
    [x addChild:p];
    
    p = [NSXMLElement elementWithName:@"field" ];
    [p addAttributeWithName:@"var"stringValue:@"muc#roomconfig_maxusers"];//最大用户
    [p addChild:[NSXMLElement elementWithName:@"value"stringValue:@"10000"]];
    [x addChild:p];
    
    p = [NSXMLElement elementWithName:@"field" ];
    [p addAttributeWithName:@"var"stringValue:@"muc#roomconfig_changesubject"];//允许改变主题
    [p addChild:[NSXMLElement elementWithName:@"value"stringValue:@"1"]];
    [x addChild:p];
    
    p = [NSXMLElement elementWithName:@"field" ];
    [p addAttributeWithName:@"var"stringValue:@"muc#roomconfig_publicroom"];//公共房间
    [p addChild:[NSXMLElement elementWithName:@"value"stringValue:@"0"]];
    [x addChild:p];
    
    p = [NSXMLElement elementWithName:@"field" ];
    [p addAttributeWithName:@"var"stringValue:@"muc#roomconfig_allowinvites"];//允许邀请
    [p addChild:[NSXMLElement elementWithName:@"value"stringValue:@"1"]];
    [x addChild:p];
    
    [xmppRoom configureRoomUsingOptions:x];
}

- (void)xmppRoom:(XMPPRoom *)sender didFetchConfigurationForm:(NSXMLElement *)configForm
{
    NSLog(@"configForm:%@",configForm);
}

// 收到禁止名单列表
- (void)xmppRoom:(XMPPRoom *)sender didFetchBanList:(NSArray *)items
{
    NSLog(@"%s",__func__);
}

// 收到成员名单列表
- (void)xmppRoom:(XMPPRoom *)sender didFetchMembersList:(NSArray *)items
{
    NSLog(@"%s",__func__);
}

// 收到主持人名单列表
- (void)xmppRoom:(XMPPRoom *)sender didFetchModeratorsList:(NSArray *)items
{
    NSLog(@"%s",__func__);
}

- (void)xmppRoom:(XMPPRoom *)sender didNotFetchBanList:(XMPPIQ *)iqError
{
    NSLog(@"%s",__func__);
}

- (void)xmppRoom:(XMPPRoom *)sender didNotFetchMembersList:(XMPPIQ *)iqError
{
    NSLog(@"%s",__func__);
}

- (void)xmppRoom:(XMPPRoom *)sender didNotFetchModeratorsList:(XMPPIQ *)iqError
{
    NSLog(@"%s",__func__);
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rooms.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"roomCell" forIndexPath:indexPath];
    
    // Configure the cell...
    DDXMLElement *item = self.rooms[indexPath.row];
    
    NSString *text = [NSString stringWithFormat:@"房间名:%@",[item attributeForName:@"name"].stringValue];
    cell.textLabel.text = text;
    cell.detailTextLabel.text = [item attributeForName:@"jid"].stringValue;
    
    return cell;
}


@end
