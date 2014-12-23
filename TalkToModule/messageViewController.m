//
//  talkToModuleViewController.m
//  MICO
//
//  Created by William Xu on 14-5-6.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "messageViewController.h"

typedef enum {
    UTF8Encoding = 1,
    HexNumberEncoding = 2,
} Encoding_Type;

#define MAX_MESSAGE_COUNT 200

static Encoding_Type encoding = UTF8Encoding;

/* transform src string to hex mode
 * example: "aabbccddee" => 0xaabbccddee
 * each char in the string must 0~9 a~f A~F, otherwise return 0
 * return the real obuf length
 */
unsigned int str2hex(unsigned char *ibuf, unsigned char *obuf,
                     unsigned int olen)
{
	unsigned int i; 	/* loop iteration variable */
	unsigned int j = 0; /* current character */
	unsigned int by = 0;	/* byte value for conversion */
	unsigned char ch;	/* current character */
	unsigned long len = strlen((char *)ibuf);
    
	/* process the list of characaters */
	for (i = 0; i < len; i++) {
		if (i == (2 * olen)) {
			// truncated it.
			return j + 1;
		}
		ch = ibuf[i];
		/* do the conversion */
		if (ch >= '0' && ch <= '9')
			by = (by << 4) + ch - '0';
		else if (ch >= 'A' && ch <= 'F')
			by = (by << 4) + ch - 'A' + 10;
		else if (ch >= 'a' && ch <= 'f')
			by = (by << 4) + ch - 'a' + 10;
		else {		/* error if not hexadecimal */
			return 0;
		}
        
		/* store a byte for each pair of hexadecimal digits */
		if (i & 1) {
			j = ((i + 1) / 2) - 1;
			obuf[j] = by & 0xff;
		}
	}
	return j + 1;
}



@interface messageViewController () <JSMessagesViewDelegate, JSMessagesViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate,UIActionSheetDelegate>

@property (strong, nonatomic) NSMutableArray *messageArray;
@property (nonatomic,strong) UIImage *willSendImage;
@property (strong, nonatomic) NSMutableArray *timestamps;
@property (strong, nonatomic) NSMutableDictionary *fileContent;
@property (strong, nonatomic) NSString *messageRecordFilePath;

@end


@implementation messageViewController
@synthesize inComingAvatarImage;
@synthesize outGoingAvatarImage;
@synthesize messageArray;
@synthesize fileContent;
@synthesize messageRecordFileName = _messageRecordFileName;
@synthesize messageRecordFilePath;

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
    NSLog(@"message alloc, %@", self);
    
    self.title = @"Talk";

    self.delegate = self;
    self.dataSource = self;
    
    if(encoding == UTF8Encoding)
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"HEX" style:UIBarButtonItemStylePlain target:self action:@selector(buttonPressed:)];
    else
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"UTF-8" style:UIBarButtonItemStylePlain target:self action:@selector(buttonPressed:)];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)releaseDelegate
{
    [self.inputToolBarView releaseDelegate];
}

- (void)dealloc{
    NSLog(@"message dealloc, %@", self);
    if([fileContent writeToFile:messageRecordFilePath atomically:NO]==YES)
        NSLog(@"write success!");
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)setMessageRecordFileName:(NSString *)newMessageRecordFileName
{
//    NSError *err;
    if (_messageRecordFileName != newMessageRecordFileName) {
        _messageRecordFileName = newMessageRecordFileName;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docPath = [paths objectAtIndex:0];
        messageRecordFilePath = [docPath stringByAppendingPathComponent:_messageRecordFileName];
        
        self.fileContent = [[NSMutableDictionary alloc] initWithContentsOfFile:messageRecordFilePath];

//        NSFileManager *defaultManager;
//        defaultManager = [NSFileManager defaultManager];
//        [defaultManager removeItemAtPath:messageRecordFilePath error:&err];
        
        if(self.fileContent == nil){
            self.messageArray = [NSMutableArray array];
            self.timestamps = [NSMutableArray array];
            self.fileContent = [NSMutableDictionary dictionary];
            NSData *initData = [[NSString stringWithFormat:@"Hello, how may I serve you?"] dataUsingEncoding:NSUTF8StringEncoding];
            [self.messageArray addObject:[NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects:initData, @YES, nil]
                                                                     forKeys: [NSArray arrayWithObjects:@"Text", @"IsRecv", nil]]];
            [self.timestamps addObject:[NSDate date]];
            [fileContent setObject:self.messageArray forKey:@"message"];
            [fileContent setObject:self.timestamps forKey:@"timestamps"];
        }
        else{
            self.messageArray = [fileContent objectForKey:@"message"];
            self.timestamps = [fileContent  objectForKey:@"timestamps"];
        }
    }
}

- (void)awakeFromNib {
    [super awakeFromNib];
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    NSLog(@"viewDidDisappear");
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)buttonPressed:(UIButton*)sender
{
    if(encoding == UTF8Encoding){
        self.navigationItem.rightBarButtonItem.title = @"UTF-8";
        encoding = HexNumberEncoding;
        
    }else{
        self.navigationItem.rightBarButtonItem.title = @"HEX";
        encoding = UTF8Encoding;
    }
    [self.tableView reloadData];
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.messageArray.count;
}

#pragma mark - Messages view delegate
- (void)sendPressed:(UIButton *)sender withText:(NSString *)text
{
    NSData *inputData;
    char* hexInASCII = nil, * hexInASCIIWithSpace = nil;
    char* hexData = nil;
    NSUInteger idx1, idx2;
    
    if(encoding == UTF8Encoding){
        inputData = [text dataUsingEncoding:NSUTF8StringEncoding];
    }else{
        /*"12 34 56 78 90 AB CD" to 0x12 0x34 0x45 0x78 0x90 0xAB 0xCD*/
        NSData *inputHexString = [text dataUsingEncoding:NSUTF8StringEncoding];
        if(inputHexString == nil) goto exit;
        hexInASCIIWithSpace = (char *)[inputHexString bytes];
        hexInASCII = malloc([inputHexString length]);
        hexData = malloc([inputHexString length]);
        for(idx1 = 0, idx2 = 0; idx1 < [inputHexString length]; ){
            if(hexInASCIIWithSpace[idx1]!=0x20){
                if((idx1+1)%3==0){
                    goto exit;
                }
                hexInASCII[idx2++]=hexInASCIIWithSpace[idx1++];
            }
            else{
                if((idx1+1)%3==0)
                    idx1++;
                else
                    goto exit;
            }
        }
        hexInASCII[idx2] = 0x0;
        
        NSUInteger len = str2hex((uint8_t *)hexInASCII, (uint8_t *)hexData,(unsigned int)[inputHexString length]);
        if(len==0) goto exit;
        
        inputData = [NSData dataWithBytes:hexData length:len];
        free(hexData);
        free(hexInASCII);
    }
    
    [self.messageArray addObject:[NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects:inputData, @NO, nil]
                                                             forKeys: [NSArray arrayWithObjects:@"Text", @"IsRecv", nil]]];
    
    [self.timestamps addObject:[NSDate date]];
    
    [JSMessageSoundEffect playMessageSentSound];
    

    
    if([messageArray count] > MAX_MESSAGE_COUNT){
        //NSUInteger needsDeleteCount = [messageArray count] - MAX_MESSAGE_COUNT;
        NSUInteger needsDeleteCount = MAX_MESSAGE_COUNT;
        NSRange range = NSMakeRange(0,needsDeleteCount);
        [messageArray removeObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange:range]];
        [self.timestamps removeObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange:range]];
    }
    
    if([self.parentViewController respondsToSelector:@selector(sendData: from:)]){
        [self.parentViewController performSelector:@selector(sendData: from:)
                                        withObject:inputData
                                        withObject:self ];
    }

    [self finishSend];
    return;
    
exit:
    if(hexData) free(hexData);
    if(hexInASCII) free(hexInASCII);
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Input Error" message:@"Please check the input format of hex number." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alertView show];
    return;
}

- (void)recvInComingData: (NSData *)data
{
    [self.messageArray addObject:[NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects:data, @YES, nil]
                                                             forKeys: [NSArray arrayWithObjects:@"Text", @"IsRecv", nil]]];
    [self.timestamps addObject:[NSDate date]];
    
    if([messageArray count] > MAX_MESSAGE_COUNT){
        //NSUInteger needsDeleteCount = [messageArray count] - MAX_MESSAGE_COUNT;
        NSUInteger needsDeleteCount = MAX_MESSAGE_COUNT;
        NSRange range = NSMakeRange(0,needsDeleteCount);
        [self.messageArray removeObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange:range]];
        [self.timestamps removeObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange:range]];
    }
    
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
}

- (void)recvOutputData: (NSData *)data
{
    [self.messageArray addObject:[NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects:data, @NO, nil]
                                                             forKeys: [NSArray arrayWithObjects:@"Text", @"IsRecv", nil]]];
    [self.timestamps addObject:[NSDate date]];
    
    if([messageArray count] > MAX_MESSAGE_COUNT){
        //NSUInteger needsDeleteCount = [messageArray count] - MAX_MESSAGE_COUNT;
        NSUInteger needsDeleteCount = MAX_MESSAGE_COUNT;
        NSRange range = NSMakeRange(0,needsDeleteCount);
        [self.messageArray removeObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange:range]];
        [self.timestamps removeObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange:range]];
    }
    
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
}

- (void)cameraPressed:(id)sender{
    
    [self.inputToolBarView.textView resignFirstResponder];
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"拍照",@"相册", nil];
    [actionSheet showInView:self.view];
}

#pragma mark -- UIActionSheet Delegate
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    
    switch (buttonIndex) {
        case 0:
            picker.sourceType = UIImagePickerControllerSourceTypeCamera;
            break;
        case 1:
            picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            break;
    }
    [self presentViewController:picker animated:YES completion:NULL];
}

- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *message = [self.messageArray objectAtIndex:indexPath.row];
    if( [[message objectForKey:@"IsRecv"] boolValue] == YES)
        return JSBubbleMessageTypeIncoming;
    else
        return JSBubbleMessageTypeOutgoing;
}

- (JSBubbleMessageStyle)messageStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return JSBubbleMessageStyleFlat;
}

- (JSBubbleMediaType)messageMediaTypeForRowAtIndexPath:(NSIndexPath *)indexPath{
    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"]){
        return JSBubbleMediaTypeText;
    }else if ([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"]){
        return JSBubbleMediaTypeImage;
    }
    
    return -1;
}

- (UIButton *)sendButton
{
    return [UIButton defaultSendButton];
}

- (JSMessagesViewTimestampPolicy)timestampPolicy
{
    /*
     JSMessagesViewTimestampPolicyAll = 0,
     JSMessagesViewTimestampPolicyAlternating,
     JSMessagesViewTimestampPolicyEveryThree,
     JSMessagesViewTimestampPolicyEveryFive,
     JSMessagesViewTimestampPolicyCustom
     */
    return JSMessagesViewTimestampPolicyAll;
}

- (JSMessagesViewAvatarPolicy)avatarPolicy
{
    /*
     JSMessagesViewAvatarPolicyIncomingOnly = 0,
     JSMessagesViewAvatarPolicyBoth,
     JSMessagesViewAvatarPolicyNone
     */
    return JSMessagesViewAvatarPolicyBoth;
}

- (JSAvatarStyle)avatarStyle
{
    /*
     JSAvatarStyleCircle = 0,
     JSAvatarStyleSquare,
     JSAvatarStyleNone
     */
    return JSAvatarStyleCircle;
}

- (JSInputBarStyle)inputBarStyle
{
    /*
     JSInputBarStyleDefault,
     JSInputBarStyleFlat
     
     */
    return JSInputBarStyleFlat;
}

//  Optional delegate method
//  Required if using `JSMessagesViewTimestampPolicyCustom`
//
//  - (BOOL)hasTimestampForRowAtIndexPath:(NSIndexPath *)indexPath
//

#pragma mark - Messages view data source
- (NSString *)textForRowAtIndexPath:(NSIndexPath *)indexPath
{
    uint8_t *cbytes;
    NSUInteger idx;
    NSData *displayData = [[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"];
    cbytes = (uint8_t *)[displayData bytes];
    if(displayData){
        if(encoding == UTF8Encoding){
            NSString *displayStringASC = [[NSString alloc] initWithData:displayData encoding:NSUTF8StringEncoding];
            return displayStringASC;
        }
        else{
            NSString *displayString = [[NSString alloc]init];
            for(idx = 0; idx< [displayData length]; idx++){
                if(idx == [displayData length] -1 ) //Last byte, remove last space
                    displayString = [displayString stringByAppendingFormat:@"%02x", cbytes[idx]];
                else
                    displayString = [displayString stringByAppendingFormat:@"%02x ", cbytes[idx]];
            }
            return displayString;
        }
    }
    return nil;
}

- (NSDate *)timestampForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.timestamps objectAtIndex:indexPath.row];
}

- (UIImage *)avatarImageForIncomingMessage
{
    return inComingAvatarImage;
}

- (UIImage *)avatarImageForOutgoingMessage
{
    return outGoingAvatarImage;
}

- (id)dataForRowAtIndexPath:(NSIndexPath *)indexPath{
    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"]){
        return [[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"];
    }
    return nil;
    
}

#pragma UIImagePicker Delegate

#pragma mark - Image picker delegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	NSLog(@"Chose image!  Details:  %@", info);
    
    self.willSendImage = [info objectForKey:UIImagePickerControllerEditedImage];
    [self.messageArray addObject:[NSDictionary dictionaryWithObject:self.willSendImage forKey:@"Image"]];
    [self.timestamps addObject:[NSDate date]];
    
    NSInteger rows = [self.tableView numberOfRowsInSection:0];
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:rows inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];
    [self.tableView endUpdates];
    
    [JSMessageSoundEffect playMessageSentSound];
    
    [self scrollToBottomAnimated:YES];
	
    [self dismissViewControllerAnimated:YES completion:NULL];
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:NULL];
    
}

/*
 Notification method handler when app enter in background
 @param the fired notification object
 */
- (void)appEnterInBackground:(NSNotification*)notification{
    if([fileContent writeToFile:messageRecordFilePath atomically:YES]==YES)
        NSLog(@"write success!");
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
