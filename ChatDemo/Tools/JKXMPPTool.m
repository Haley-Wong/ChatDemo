//
//  JKXMPPTool.m
//  ChatDemo
//
//  Created by Joker on 15/7/19.
//  Copyright (c) 2015年 Mac. All rights reserved.
//

#import "JKXMPPTool.h"

@interface JKXMPPTool ()

@property (strong, nonatomic)   NSMutableDictionary            *blockDict;  /**< 存放block的字典 */

@end

@implementation JKXMPPTool

static JKXMPPTool *_instance;
+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [JKXMPPTool new];
        _instance.blockDict = [NSMutableDictionary dictionary];
    });
    
    return _instance;
}

- (XMPPStream *)xmppStream
{
    if (!_xmppStream) {
        _xmppStream = [[XMPPStream alloc] init];
        
        //socket 连接的时候 要知道host port 然后connect
        [self.xmppStream setHostName:kXMPP_HOST];
        [self.xmppStream setHostPort:kXMPP_PORT];
        //为什么是addDelegate? 因为xmppFramework 大量使用了多播代理multicast-delegate ,代理一般是1对1的，但是这个多播代理是一对多得，而且可以在任意时候添加或者删除
        [self.xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
        
        //添加功能模块
        //1.autoPing 发送的时一个stream:ping 对方如果想表示自己是活跃的，应该返回一个pong
        _xmppAutoPing = [[XMPPAutoPing alloc] init];
        //所有的Module模块，都要激活active
        [_xmppAutoPing activate:self.xmppStream];
        
        //autoPing由于它会定时发送ping,要求对方返回pong,因此这个时间我们需要设置
        [_xmppAutoPing setPingInterval:1000];
        //不仅仅是服务器来得响应;如果是普通的用户，一样会响应
        [_xmppAutoPing setRespondsToQueries:YES];
        //这个过程是C---->S  ;观察 S--->C(需要在服务器设置）
        
        //2.autoReconnect 自动重连，当我们被断开了，自动重新连接上去，并且将上一次的信息自动加上去
        _xmppReconnect = [[XMPPReconnect alloc] init];
        [_xmppReconnect activate:self.xmppStream];
        [_xmppReconnect setAutoReconnect:YES];
        
        
         // 3.好友模块 支持我们管理、同步、申请、删除好友
        _xmppRosterMemoryStorage = [[XMPPRosterMemoryStorage alloc] init];
        _xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:_xmppRosterMemoryStorage];
        [_xmppRoster activate:self.xmppStream];
        
        //同时给_xmppRosterMemoryStorage 和 _xmppRoster都添加了代理
        [_xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
        //设置好友同步策略,XMPP一旦连接成功，同步好友到本地
        [_xmppRoster setAutoFetchRoster:YES]; //自动同步，从服务器取出好友
        //关掉自动接收好友请求，默认开启自动同意
        [_xmppRoster setAutoAcceptKnownPresenceSubscriptionRequests:NO];
        
        //4.消息模块，这里用单例，不能切换账号登录，否则会出现数据问题。
        _xmppMessageArchivingCoreDataStorage = [XMPPMessageArchivingCoreDataStorage sharedInstance];
        _xmppMessageArchiving = [[XMPPMessageArchiving alloc] initWithMessageArchivingStorage:_xmppMessageArchivingCoreDataStorage dispatchQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 9)];
        [_xmppMessageArchiving activate:self.xmppStream];
        
        //5、文件接收
        _xmppIncomingFileTransfer = [[XMPPIncomingFileTransfer alloc] initWithDispatchQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)];
        [_xmppIncomingFileTransfer activate:self.xmppStream];
        [_xmppIncomingFileTransfer addDelegate:self delegateQueue:dispatch_get_main_queue()];
        [_xmppIncomingFileTransfer setAutoAcceptFileTransfers:YES];
    }
    return _xmppStream;
}

- (void)loginWithJID:(XMPPJID *)JID andPassword:(NSString *)password
{
    // 1.建立TCP连接
    // 2.把我自己的jid与这个TCP连接绑定起来
    // 3.认证（登录：验证jid与密码是否正确，加密方式 不可能以明文发送）--（出席：怎样告诉服务器我上线，以及我得上线状态
    //这句话会在xmppStream以后发送XML的时候加上 <message from="JID">
    [self.xmppStream setMyJID:JID];
    self.myPassword = password;
    self.xmppNeedRegister = NO;
    [self.xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:nil];
}

//注册方法里没有调用auth方法
- (void)registerWithJID:(XMPPJID *)JID andPassword:(NSString *)password
{
    [self.xmppStream setMyJID:JID];
    self.myPassword = password;
    self.xmppNeedRegister = YES;
    [self.xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:nil];
}

- (void)addFriend:(XMPPJID *)aJID
{
    //这里的nickname是我对它的备注，并非他得个人资料中得nickname
    [self.xmppRoster addUser:aJID withNickname:@"好友"];
}

- (void)goOnline
{
    // 发送一个<presence/> 默认值avaliable 在线 是指服务器收到空的presence 会认为是这个
    // status ---自定义的内容，可以是任何的。
    // show 是固定的，有几种类型 dnd、xa、away、chat，在方法XMPPPresence 的intShow中可以看到
    XMPPPresence *presence = [XMPPPresence presence];
    [presence addChild:[DDXMLNode elementWithName:@"status" stringValue:@"我现在很忙"]];
    [presence addChild:[DDXMLNode elementWithName:@"show" stringValue:@"xa"]];
    
    [self.xmppStream sendElement:presence];
}

/**
 *  退出登录
 */
- (void)logout
{
    [self.xmppStream disconnect];
    [self.xmppStream removeDelegate:self];
    self.xmppReconnect.autoReconnect = NO;
    [self.xmppReconnect deactivate];
    [self.xmppAutoPing deactivate];
    [self.xmppRoster deactivate];
    [self.xmppMessageArchiving deactivate];
    [self.xmppIncomingFileTransfer deactivate];
    self.xmppStream = nil;
}

#pragma mark ===== XMPPStream delegate =======
//socket 连接建立成功
- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket
{
    NSLog(@"%s",__func__);
}

//这个是xml流初始化成功
- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    if (self.xmppNeedRegister) {
        BOOL result = [self.xmppStream registerWithPassword:self.myPassword error:nil];
        NSNumber *number = [NSNumber numberWithBool:result];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kREGIST_RESULT object:number];
        
    } else {
        [self.xmppStream authenticateWithPassword:self.myPassword error:nil];
    }
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    NSLog(@"%s",__func__);
}

//登录失败
- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(DDXMLElement *)error
{
    NSLog(@"%s",__func__);
}

//登录成功
- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    [self goOnline];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kLOGIN_SUCCESS object:nil];
}

#pragma mark ===== 好友模块 委托=======
/** 收到出席订阅请求（代表对方想添加自己为好友) */
- (void)xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence
{
    //添加好友一定会订阅对方，但是接受订阅不一定要添加对方为好友
    self.receivePresence = presence;
    
    NSString *message = [NSString stringWithFormat:@"【%@】想加你为好友",presence.from.bare];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:self cancelButtonTitle:@"拒绝" otherButtonTitles:@"同意", nil];
    [alertView show];
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    //收到对方取消定阅我得消息
    if ([presence.type isEqualToString:@"unsubscribe"]) {
        //从我的本地通讯录中将他移除
        [self.xmppRoster removeUser:presence.from];
    }
}

/**
 * 开始同步服务器发送过来的自己的好友列表
 **/
- (void)xmppRosterDidBeginPopulating:(XMPPRoster *)sender
{
    
}

/**
 * 同步结束
 **/
//收到好友列表IQ会进入的方法，并且已经存入我的存储器
- (void)xmppRosterDidEndPopulating:(XMPPRoster *)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kXMPP_ROSTER_CHANGE object:nil];
}

//收到每一个好友
- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterItem:(NSXMLElement *)item
{
    
}

// 如果不是初始化同步来的roster,那么会自动存入我的好友存储器
- (void)xmppRosterDidChange:(XMPPRosterMemoryStorage *)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kXMPP_ROSTER_CHANGE object:nil];
}

#pragma mark ===== 文件接收=======
/** 是否同意对方发文件给我 */
- (void)xmppIncomingFileTransfer:(XMPPIncomingFileTransfer *)sender didReceiveSIOffer:(XMPPIQ *)offer
{
    NSLog(@"%s",__FUNCTION__);
    //弹出一个是否接收的询问框
//    [self.xmppIncomingFileTransfer acceptSIOffer:offer];
}

- (void)xmppIncomingFileTransfer:(XMPPIncomingFileTransfer *)sender didSucceedWithData:(NSData *)data named:(NSString *)name
{
    XMPPJID *jid = [sender.senderJID copy];
    NSLog(@"%s",__FUNCTION__);
    //在这个方法里面，我们通过带外来传输的文件
    //因此我们的消息同步器，不会帮我们自动生成Message,因此我们需要手动存储message
    //根据文件后缀名，判断文件我们是否能够处理，如果不能处理则直接显示。
    //图片 音频 （.wav,.mp3,.mp4)
    NSString *extension = [name pathExtension];
    if (![@"wav" isEqualToString:extension]) {
        return;
    }
    //创建一个XMPPMessage对象,message必须要有from
    XMPPMessage *message = [XMPPMessage messageWithType:@"chat" to:jid];
    //将这个文件的发送者添加到Message的from
    [message addAttributeWithName:@"from" stringValue:sender.senderJID.bare];
    [message addSubject:@"audio"];
    
    //保存data
    NSString *path =  [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:[XMPPStream generateUUID]];
    path = [path stringByAppendingPathExtension:@"wav"];
    [data writeToFile:path atomically:YES];
    
    [message addBody:path.lastPathComponent];
    
    [self.xmppMessageArchivingCoreDataStorage archiveMessage:message outgoing:NO xmppStream:self.xmppStream];
}

#pragma mark - Message
- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    NSLog(@"%s--%@",__FUNCTION__, message);
    //XEP--0136 已经用coreData实现了数据的接收和保存
    
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSLog(@"iq:%@",iq);
    // 以下两个判断其实只需要有一个就够了
    NSString *elementID = iq.elementID;
    if (![elementID isEqualToString:@"getMyRooms"]) {
        return YES;
    }
    
    NSArray *results = [iq elementsForXmlns:@"http://jabber.org/protocol/disco#items"];
    if (results.count < 1) {
        return YES;
    }
    
    NSMutableArray *array = [NSMutableArray array];
    for (DDXMLElement *element in iq.children) {
        if ([element.name isEqualToString:@"query"]) {
            for (DDXMLElement *item in element.children) {
                if ([item.name isEqualToString:@"item"]) {
                    [array addObject:item];          //array  就是你的群列表
                    
                }
            }
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kXMPP_GET_GROUPS object:array];
    
    return YES;
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        NSLog(@"0000");
        [self.xmppRoster rejectPresenceSubscriptionRequestFrom:_receivePresence.from];
    } else {
        [self.xmppRoster acceptPresenceSubscriptionRequestFrom:_receivePresence.from andAddToRoster:YES];
    }
}


@end
