/*
 * Copyright 2013 shrtlist.com
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "GKTestViewController.h"

@implementation GKTestViewController
{
    GKSession *_gkSession;
}

// Non-global constants
static NSTimeInterval const kConnectionTimeout = 5.0;
static NSTimeInterval const kDisconnectTimeout = 5.0;
static NSTimeInterval const kSleepTimeInterval = 0.5;
static NSString *const kSectionFooterTitle = @"Note that states are not mutually exclusive. For example, a peer can be available for other peers to discover while it is attempting to connect to another peer.";

#pragma mark - GKSession setup and teardown

- (void)setupSession
{
    _gkSession = [[GKSession alloc] initWithSessionID:nil displayName:nil sessionMode:GKSessionModePeer];
    _gkSession.delegate = self;
    _gkSession.disconnectTimeout = kDisconnectTimeout;
    _gkSession.available = YES;
    
    self.title = [NSString stringWithFormat:@"GKSession: %@", _gkSession.displayName];
}

- (void)teardownSession
{
    [_gkSession disconnectFromAllPeers];
    _gkSession.available = NO;
    _gkSession.delegate = nil;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupSession];
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

    // Register for notifications when the application leaves the background state
    // on its way to becoming the active application.
    [defaultCenter addObserver:self 
                      selector:@selector(setupSession) 
                          name:UIApplicationWillEnterForegroundNotification
                        object:nil];

    // Register for notifications when when the application enters the background.
    [defaultCenter addObserver:self 
                      selector:@selector(teardownSession) 
                          name:UIApplicationDidEnterBackgroundNotification 
                        object:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    }
    else
    {
        return YES;
    }
}

#pragma mark - Memory management

- (void)dealloc
{
    // Unregister for notifications on deallocation.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - GKSessionDelegate protocol conformance

- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state
{	
	switch (state)
	{
		case GKPeerStateAvailable:
        {
			NSLog(@"didChangeState: peer %@ available", [session displayNameForPeer:peerID]);

            [NSThread sleepForTimeInterval:kSleepTimeInterval];

			[session connectToPeer:peerID withTimeout:kConnectionTimeout];
			break;
        }
			
		case GKPeerStateUnavailable:
        {
			NSLog(@"didChangeState: peer %@ unavailable", [session displayNameForPeer:peerID]);
			break;
        }
			
		case GKPeerStateConnected:
        {
			NSLog(@"didChangeState: peer %@ connected", [session displayNameForPeer:peerID]);
			break;
        }
			
		case GKPeerStateDisconnected:
        {
			NSLog(@"didChangeState: peer %@ disconnected", [session displayNameForPeer:peerID]);
			break;
        }
			
		case GKPeerStateConnecting:
        {
			NSLog(@"didChangeState: peer %@ connecting", [session displayNameForPeer:peerID]);
			break;
        }
	}
	
	[self.tableView reloadData];
}

- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID
{
	NSLog(@"didReceiveConnectionRequestFromPeer: %@", [session displayNameForPeer:peerID]);

    [session acceptConnectionFromPeer:peerID error:nil];
	
	[self.tableView reloadData];
}

- (void)session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error
{
	NSLog(@"connectionWithPeerFailed: peer: %@, error: %@", [session displayNameForPeer:peerID], error);
	
	[self.tableView reloadData];
}

- (void)session:(GKSession *)session didFailWithError:(NSError *)error
{
	NSLog(@"didFailWithError: error: %@", error);
	
	[session disconnectFromAllPeers];
	
	[self.tableView reloadData];
}

#pragma mark - UITableViewDataSource protocol conformance

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // We have 5 sections in our grouped table view,
    // one for each GKPeerConnectionState
	return 5;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    NSInteger rows;
    
    NSInteger peerConnectionState = section;
    
    switch (peerConnectionState)
    {
        case GKPeerStateAvailable:
        {
            NSArray *availablePeers = [_gkSession peersWithConnectionState:GKPeerStateAvailable];
            rows = availablePeers.count;
            break;
        }

        case GKPeerStateConnecting:
        {
            NSArray *connectingPeers = [_gkSession peersWithConnectionState:GKPeerStateConnecting];
            rows = connectingPeers.count;
            break;
        }
            
        case GKPeerStateConnected:
        {
            NSArray *connectedPeers = [_gkSession peersWithConnectionState:GKPeerStateConnected];
            rows = connectedPeers.count;
            break;
        }
            
        case GKPeerStateDisconnected:
        {
            NSArray *disconnectedPeers = [_gkSession peersWithConnectionState:GKPeerStateDisconnected];
            rows = disconnectedPeers.count;
            break;
        }
            
        case GKPeerStateUnavailable:
        {
            NSArray *unavailablePeers = [_gkSession peersWithConnectionState:GKPeerStateUnavailable];
            rows = unavailablePeers.count;
            break;
        }
    }
    
    // Always show at least 1 row for each GKPeerConnectionState.
    if (rows < 1)
    {
        rows = 1;
    }
    
	return rows;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{    
    NSString *headerTitle = nil;
    
    NSInteger peerConnectionState = section;

    switch (peerConnectionState)
    {
        case GKPeerStateAvailable:
        {
            headerTitle = @"Available Peers";
            break;
        }
            
        case GKPeerStateConnecting:
        {
            headerTitle = @"Connecting Peers";
            break;
        }

        case GKPeerStateConnected:
        {
            headerTitle = @"Connected Peers";
            break;
        }

        case GKPeerStateDisconnected:
        {
            headerTitle = @"Disconnected Peers";
            break;
        }
            
        case GKPeerStateUnavailable:
        {
            headerTitle = @"Unavailable Peers";
            break;
        }
    }
	
	return headerTitle;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    cell.textLabel.text = @"None";
	
    NSInteger peerConnectionState = indexPath.section;

	NSArray *peers = nil;

    switch (peerConnectionState)
    {
        case GKPeerStateAvailable:
        {
            peers = [_gkSession peersWithConnectionState:GKPeerStateAvailable];
            break;
        }
            
        case GKPeerStateConnecting:
        {
            peers = [_gkSession peersWithConnectionState:GKPeerStateConnecting];
            break;
        }
            
        case GKPeerStateConnected:
        {
            peers = [_gkSession peersWithConnectionState:GKPeerStateConnected];
            break;
        }
            
        case GKPeerStateDisconnected:
        {
            peers = [_gkSession peersWithConnectionState:GKPeerStateDisconnected];
            break;
        }
            
        case GKPeerStateUnavailable:
        {
            peers = [_gkSession peersWithConnectionState:GKPeerStateUnavailable];
            break;
        }
    }

	NSInteger peerIndex = indexPath.row;
    
    if ((peers.count > 0) && (peerIndex < peers.count))
    {
        NSString *peerID = [peers objectAtIndex:peerIndex];
        
        if (peerID)
        {
            cell.textLabel.text = [_gkSession displayNameForPeer:peerID];
        }
    }
	
	return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSString *title = nil;

    if (section == GKPeerStateConnecting)
    {
        title = kSectionFooterTitle;
    }
    
    return title;
}

@end
