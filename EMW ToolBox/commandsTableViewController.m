//
//  commandsTableViewController.m
//  MICO
//
//  Created by William Xu on 14-5-8.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "commandsTableViewController.h"
#import "UIViewController+KNSemiModal.h"

#define Key_Title       @"Title"
#define Key_Content     @"Content"
#define Key_Type        @"Type"

#define Type_String     @"string"
#define Type_Hex        @"hex"

char* DataToHexStringWithSpaces( const uint8_t *inBuf, size_t inBufLen )
{
    char* buf_str = NULL;
    char* buf_ptr = NULL;
    
    buf_str = (char*) malloc (3*inBufLen + 1);
    buf_ptr = buf_str;
    uint32_t i;
    for (i = 0; i < inBufLen; i++) buf_ptr += sprintf(buf_ptr, "%02X ", inBuf[i]);
    *(buf_ptr + 1) = '\0';
    return buf_str;
    
error:
    if ( buf_str ) free( buf_str );
    return NULL;
}


@interface commandsTableViewController ()
@property (strong, nonatomic) NSMutableArray *commandList;
@property (strong, nonatomic) NSString *commandRecordFilePath;

- (void)autoSend:(NSTimer*)timer;

@end

@implementation commandsTableViewController
@synthesize protocol = _protocol;
@synthesize commandList;
@synthesize commandRecordFilePath;


- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Commands";
    editing = NO;
    autoSending = NO;
    

   
    bgv = [[UIView alloc]init];
    [bgv setBackgroundColor:[UIColor colorWithRed:0 green:122.0/255 blue:1 alpha:1]];
        
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated
{
    commandSender = self.parentViewController;
}

- (void)dealloc{
    NSLog(@"command dealloc");
}

- (void)setProtocol:(NSString *)newProtocol
{
        if (_protocol != newProtocol) {
        _protocol = newProtocol;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docPath = [paths objectAtIndex:0];
        commandRecordFilePath = [docPath stringByAppendingPathComponent:_protocol];
        
        self.commandList = [[NSMutableArray alloc] initWithContentsOfFile:commandRecordFilePath];
        
        if(self.commandList == nil){
            
            self.commandList = [NSMutableArray arrayWithCapacity:20];
            NSString *commandTitle = @"Command 1: Demo String";
            NSString *commandContentString = @"Show your self!";
            uint8_t commandContentCBytes[40] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99};
            NSData *commandContentData = [commandContentString dataUsingEncoding:NSUTF8StringEncoding];
            NSMutableDictionary *command = [NSMutableDictionary dictionaryWithObjectsAndKeys:commandTitle, Key_Title,
                                            commandContentData, Key_Content, Type_String, Key_Type, nil];
            
            [self.commandList addObject:command];
            
            commandTitle = @"Command 2: Demo Hex";
            commandContentData = [NSData dataWithBytes:commandContentCBytes length:10];
            command = [NSMutableDictionary dictionaryWithObjectsAndKeys:commandTitle, Key_Title,
                                            commandContentData, Key_Content, Type_Hex, Key_Type, nil];
            
            [self.commandList addObject:command];
            
        }
    }
}


- (IBAction)reOrderCommand:(UIBarButtonItem *)sender
{
    if(editing == false){
        editButton.title = @"Done";
        [commandTableView setEditing:YES animated:YES];
        editing = true;
    }else{
        editButton.title = @"Edit";
        [commandTableView setEditing:NO animated:YES];
        editing = false;
    }
    
}

- (IBAction)autoSendCommand:(UIBarButtonItem *)sender
{
    if(autoSending == NO){
        currentSendIndex = 0;
        
        UIActionSheet *action = [[UIActionSheet alloc] initWithTitle:@"Select Time Interval"
                                                            delegate:self
                                                   cancelButtonTitle:@"Cancel"
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:@"Interval 0.1 seconds",
                                 @"Interval 0.5 seconds", @"Interval 1 seconds", @"Interval 5 seconds", @"Interval 20 seconds",nil];
        [action showInView:self.view];
        
        //autoSendTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(autoSend:) userInfo:nil repeats:YES];
        //sender.title = @"Stop";
        //autoSending = YES;
    }else{
        NSUInteger index = (--currentSendIndex)%[self.commandList count];
        [commandTableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]
                                        animated:YES];
        [autoSendTimer invalidate];
        autoSending = NO;
        sender.title = @"Auto";
    }
}

#pragma mark -- UIActionSheet Delegate
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    switch (buttonIndex) {
        case 0:
            autoSendTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(autoSend:) userInfo:nil repeats:YES];
            break;
        case 1:
            autoSendTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(autoSend:) userInfo:nil repeats:YES];
            break;
        case 2:
            autoSendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(autoSend:) userInfo:nil repeats:YES];
            break;
        case 3:
            autoSendTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(autoSend:) userInfo:nil repeats:YES];
            break;
        case 4:
            autoSendTimer = [NSTimer scheduledTimerWithTimeInterval:20.0f target:self selector:@selector(autoSend:) userInfo:nil repeats:YES];
            break;
    }
    autoButton.title = @"Stop";
    autoSending = YES;
}

- (void)autoSend:(NSTimer*)timer
{
    NSUInteger index = (currentSendIndex++)%[self.commandList count];
    NSDictionary *commandDetail = [self.commandList objectAtIndex:index];
    
    [commandTableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]
                                  animated:YES
                            scrollPosition:UITableViewScrollPositionMiddle];
    
    if([commandSender respondsToSelector:@selector(sendData: from:)]){
        [commandSender performSelector:@selector(sendData: from:)
                                        withObject:[commandDetail objectForKey:Key_Content]
                                        withObject:self ];
    }
}


- (void)getNewCommand:(NSString *)subject content:(NSData *)content  type: (NSString *)type
{
    NSIndexPath *indexPath;
    NSDictionary *command = [NSDictionary dictionaryWithObjectsAndKeys:subject, Key_Title,
                                    content, Key_Content, type, Key_Type, nil];
    indexPath  = [NSIndexPath indexPathForRow:indexNeedsChange inSection:0];
    
    if(indexNeedsChange == [self.commandList count]){
        [self.commandList addObject:command];
        [commandTableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]  withRowAnimation:UITableViewRowAnimationRight];
    }else{
        [self.commandList replaceObjectAtIndex:indexNeedsChange withObject:command];
        [commandTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]  withRowAnimation:UITableViewRowAnimationRight];
    }
    
    if([self.commandList writeToFile:commandRecordFilePath atomically:YES]==YES)
        NSLog(@"write success!");
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.commandList count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Command" forIndexPath:indexPath];
    NSDictionary *commandDetail = [self.commandList objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [commandDetail objectForKey:Key_Title];
    NSString *type = [commandDetail objectForKey:Key_Type];
    NSData *data = [commandDetail objectForKey:Key_Content];
    
    if([type isEqualToString:Type_String]){
        cell.detailTextLabel.text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }else if([type isEqualToString:Type_Hex]){
        cell.detailTextLabel.text = [NSString stringWithCString:DataToHexStringWithSpaces([data bytes], [data length])
                                                       encoding:NSUTF8StringEncoding];
    }
    cell.showsReorderControl = YES;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @"Command list";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *commandDetail = [self.commandList objectAtIndex:indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    

    if([commandSender respondsToSelector:@selector(sendData: from:)]){
        [commandSender performSelector:@selector(sendData: from:)
                                        withObject:[commandDetail objectForKey:Key_Content]
                                        withObject:self ];
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)path
{
    if(autoSending == YES){
        return nil;
    }else{
        return path;
    }
}



- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger row = [indexPath row];
    [self.commandList removeObjectAtIndex:row];
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
    if([self.commandList writeToFile:commandRecordFilePath atomically:YES]==YES)
        NSLog(@"write success!");
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    [self.commandList exchangeObjectAtIndex:fromIndexPath.row withObjectAtIndex:toIndexPath.row];
}



// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}



#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([[segue identifier] isEqualToString:@"Add command"]) {
        indexNeedsChange = [self.commandList count];
        [[segue destinationViewController] setDelegate:self];
        NSString *emptyCommand = @"Empty";
        [[segue destinationViewController] setSubject: @"New Command"
                                           withDetail:[emptyCommand dataUsingEncoding:NSUTF8StringEncoding]
                                              forType: @"string"];

    }
    if ([[segue identifier] isEqualToString:@"Edit command"]) {
        UITableViewCell *cell;
        NSIndexPath *indexPath;
        NSLog(@"Value changed!");
        cell = (UITableViewCell *)sender;
        indexPath = [commandTableView indexPathForCell:cell];
        NSDictionary *command = [commandList objectAtIndex:indexPath.row];
        [[segue destinationViewController] setSubject: [command objectForKey:Key_Title]
                                           withDetail: [command objectForKey:Key_Content]
                                              forType: [command objectForKey:Key_Type]];

        
        indexNeedsChange = indexPath.row;
        [[segue destinationViewController] setDelegate:self];
    }
    
}


@end
