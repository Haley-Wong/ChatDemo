//
//  ChatViewController.m
//  ChatDemo
//
//  Created by Joker on 15/7/22.
//  Copyright (c) 2015年 Mac. All rights reserved.
//

#import "ChatViewController.h"

#import "JKXMPPTool.h"

@interface ChatViewController ()<XMPPOutgoingFileTransferDelegate>

@property (weak, nonatomic) IBOutlet UITableView *messageTableView;
@property (weak, nonatomic) IBOutlet UIView *bottomView;
@property (weak, nonatomic) IBOutlet UITextField *chatTextField;

@property (nonatomic, retain) AVAudioRecorder   *recorder;
@property (nonatomic, retain) AVAudioPlayer     *player;

@property (nonatomic, strong) XMPPOutgoingFileTransfer *xmppOutgoingFileTransfer;


@end

@implementation ChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = _chatJID.user;
    self.view.backgroundColor = RGBColor(234, 239, 245, 1);
    
    self.messageTableView.rowHeight = 60;
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyBoard)];
    [_messageTableView addGestureRecognizer:tapGesture];
    
    [self getChatHistory];
    
    [self addNotifications];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kXMPP_MESSAGE_CHANGE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    
    [_xmppOutgoingFileTransfer removeDelegate:self];
    [_xmppOutgoingFileTransfer deactivate];
    _xmppOutgoingFileTransfer = nil;
}

- (void)addNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getChatHistory) name:kXMPP_MESSAGE_CHANGE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillSHow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

#pragma mark - private method
/** 发送的事件 */
- (void)sendMessage{
    if (_chatTextField.text.length < 1) {
        return;
    }
    XMPPMessage *message = [XMPPMessage messageWithType:@"chat" to:self.chatJID];
    [message addBody:_chatTextField.text];
    [[JKXMPPTool sharedInstance].xmppStream sendElement:message];
    
    _chatTextField.text = @"";
    
    [self tableViewScrollToBottom];
}

/** 查询聊天记录 */
- (void)getChatHistory
{
    XMPPMessageArchivingCoreDataStorage *storage = [JKXMPPTool sharedInstance].xmppMessageArchivingCoreDataStorage;
    //查询的时候要给上下文
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:storage.messageEntityName inManagedObjectContext:storage.mainThreadManagedObjectContext];
    [fetchRequest setEntity:entity];
    // Specify criteria for filtering which objects to fetch
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"bareJidStr = %@", self.chatJID.bare];
    [fetchRequest setPredicate:predicate];
    // Specify how the fetched objects should be sorted
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timestamp"
                                                                   ascending:YES];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObjects:sortDescriptor, nil]];
    
    NSError *error = nil;
    NSArray *fetchedObjects = [storage.mainThreadManagedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (fetchedObjects != nil) {
        self.chatHistory = [[NSMutableArray alloc] initWithArray:fetchedObjects];
        //        [NSMutableArray arrayWithArray:fetchedObjects];
    }
    
    [self.messageTableView reloadData];
    
    [self tableViewScrollToBottom];
}

- (void)tableViewScrollToBottom
{
    if (_chatHistory.count > 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(_chatHistory.count-1) inSection:0];
        [self.messageTableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (XMPPOutgoingFileTransfer *)xmppOutgoingFileTransfer
{
    if (!_xmppOutgoingFileTransfer) {
        _xmppOutgoingFileTransfer = [[XMPPOutgoingFileTransfer alloc] initWithDispatchQueue:dispatch_get_global_queue(0, 0)];
        [_xmppOutgoingFileTransfer activate:[JKXMPPTool sharedInstance].xmppStream];
        [_xmppOutgoingFileTransfer addDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
    }
    return _xmppOutgoingFileTransfer;
}

- (void)playVoice:(UIButton *)btn
{
    XMPPMessageArchiving_Message_CoreDataObject *message = self.chatHistory[btn.tag];
    NSString *path =  [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:message.body];
    NSURL *url = [NSURL URLWithString:path];
    
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    [self.player prepareToPlay];
    [self.player play];
}

- (IBAction)startRecord:(id)sender {
    NSString *path =  [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:[XMPPStream generateUUID]];
    path = [path stringByAppendingPathExtension:@"wav"];
    
    NSURL *URL = [NSURL fileURLWithPath:path];
    _recorder = [[AVAudioRecorder alloc] initWithURL:URL settings:nil error:nil];
    [_recorder prepareToRecord];
    [_recorder record];
}

- (IBAction)sendRecord:(id)sender {
    [_recorder stop];
    NSArray *resources = [[JKXMPPTool sharedInstance].xmppRosterMemoryStorage sortedResources:YES];
    for (XMPPResourceMemoryStorageObject *object in resources) {
        if ([object.jid.bare isEqualToString:self.chatJID.bare]) {
            NSData *data = [[[NSData alloc] initWithContentsOfURL:_recorder.url] copy];
            NSError *err;
            [self.xmppOutgoingFileTransfer sendData:data named:_recorder.url.lastPathComponent toRecipient:object.jid description:nil error:&err];
            if (err) {
                NSLog(@"%@",err);
            }
            break;
        }
    }
    
    _recorder = nil;
}

- (IBAction)cancelRecord:(id)sender {
    [_recorder stop];
    [[NSFileManager defaultManager] removeItemAtURL:_recorder.url error:nil];
    _recorder = nil;
}

#pragma mark - notification event
- (void)hideKeyBoard
{
    [self.view endEditing:YES];
}

- (void)keyboardWillSHow:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    CGSize size = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    NSNumber *duration = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    
    [UIView animateWithDuration:duration.doubleValue animations:^{
        _bottomView.transform = CGAffineTransformMakeTranslation(0, -size.height);
        CGRect rect = _messageTableView.frame;
        rect.size.height = kScreenHeight-50-size.height;
        _messageTableView.frame = rect;
        [self tableViewScrollToBottom];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSNumber *duration = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    
    [UIView animateWithDuration:duration.doubleValue animations:^{
        _bottomView.transform = CGAffineTransformIdentity;
        CGRect rect = _messageTableView.frame;
        rect.size.height = kScreenHeight-50;
        _messageTableView.frame = rect;
    }];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self sendMessage];
    return YES;
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.chatHistory.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //先判断这个消息显示在哪边
    XMPPMessageArchiving_Message_CoreDataObject *message = self.chatHistory[indexPath.row];
    NSString *identifier = message.isOutgoing?@"TextMessageRight":@"TextMessageLeft";
    if ([message.message.subject isEqualToString:@"audio"]) {
        identifier = message.isOutgoing?@"AudioMessageRight":@"AudioMessageLeft";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        
        UIButton *btn = (UIButton*)[cell viewWithTag:10002];
        btn.tag = indexPath.row;
        [btn addTarget:self action:@selector(playVoice:) forControlEvents:UIControlEventTouchUpInside];
        return cell;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    UILabel *contentLabel = (UILabel *)[cell viewWithTag:10002];
    contentLabel.text = message.body;
    
    return cell;
}

#pragma mark - 文件发送代理
- (void)xmppOutgoingFileTransfer:(XMPPOutgoingFileTransfer *)sender
                didFailWithError:(NSError *)error
{
    NSLog(@"didFailWithError:%@",error);
}

- (void)xmppOutgoingFileTransferDidSucceed:(XMPPOutgoingFileTransfer *)sender
{
    NSLog(@"xmppOutgoingFileTransferDidSucceed");
    
    XMPPMessage *message = [XMPPMessage messageWithType:@"chat" to:self.chatJID];
    
    //将这个文件的发送者添加到message的from
    [message addAttributeWithName:@"from" stringValue:[JKXMPPTool sharedInstance].xmppStream.myJID.bare];
    [message addSubject:@"audio"];
    
    NSString *path =  [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:sender.outgoingFileName];
    
    [message addBody:path.lastPathComponent];
    
    [[JKXMPPTool sharedInstance].xmppMessageArchivingCoreDataStorage archiveMessage:message outgoing:NO xmppStream:[JKXMPPTool sharedInstance].xmppStream];
}

@end
