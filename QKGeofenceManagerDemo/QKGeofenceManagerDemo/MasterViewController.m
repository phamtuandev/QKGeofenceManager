//
//  MasterViewController.m
//  QKGeofenceManagerDemo
//
//  Created by Eric Webster on 2014-08-25.
//  Copyright (c) 2014 Eric Webster. All rights reserved.
//

#import "MasterViewController.h"
#import "DetailViewController.h"

@interface MasterViewController ()

@property (nonatomic) NSMutableSet *insideGeofenceIds;
@property (nonatomic) NSMutableArray *rightBarButtonItems;
@property (nonatomic) CLLocationManager *locationManager;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end

@implementation MasterViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadGeofences)];
    
    self.rightBarButtonItems = [NSMutableArray arrayWithObjects:refreshButton, addButton, nil];
    self.navigationItem.rightBarButtonItems = self.rightBarButtonItems;
    
    // Get an initial fix on user's current location. Used as a default for new geofences.
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    [self.locationManager startUpdatingLocation];
    
    [self reloadGeofences];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)reloadGeofences
{
    self.insideGeofenceIds = [NSMutableSet set];
    
    QKGeofenceManager *geofenceManager = [QKGeofenceManager sharedGeofenceManager];
    geofenceManager.delegate = self;
    geofenceManager.dataSource = self;
    [geofenceManager reloadGeofences];
}

- (void)insertNewObject:(id)sender
{
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
    
    // If appropriate, configure the new managed object.
    // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
    [newManagedObject setValue:[NSDate date] forKey:@"timeStamp"];
    [newManagedObject setValue:@(self.locationManager.location.coordinate.latitude) forKey:@"lat"];
    [newManagedObject setValue:@(self.locationManager.location.coordinate.longitude) forKey:@"lon"];
    [newManagedObject setValue:@20 forKey:@"radius"];
    
    NSInteger n = [self tableView:self.tableView numberOfRowsInSection:0];
    NSString *identifier = [NSString stringWithFormat:@"Geofence-%i", n+1];
    [newManagedObject setValue:identifier forKey:@"identifier"];
    
    // Save the context.
    NSError *error = nil;
    if (![context save:&error]) {
         // Replace this implementation with code to handle the error appropriately.
         // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}

#pragma mark - Geofence Manager

- (NSArray *)geofencesForGeofenceManager:(QKGeofenceManager *)geofenceManager
{
    NSArray *fetchedObjects = [self.fetchedResultsController fetchedObjects];
    NSMutableArray *geofences = [NSMutableArray arrayWithCapacity:[fetchedObjects count]];
    for (NSManagedObject *object in fetchedObjects) {
        NSString *identifier = [object valueForKey:@"identifier"];
        CLLocationDegrees lat = [[object valueForKey:@"lat"] doubleValue];
        CLLocationDegrees lon = [[object valueForKey:@"lon"] doubleValue];
        CLLocationDistance radius = [[object valueForKey:@"radius"] doubleValue];
        CLLocationCoordinate2D center = CLLocationCoordinate2DMake(lat, lon);
        CLCircularRegion *geofence = [[CLCircularRegion alloc] initWithCenter:center radius:radius identifier:identifier];
        [geofences addObject:geofence];
    }
    return geofences;
}

- (void)geofenceManager:(QKGeofenceManager *)geofenceManager isInsideGeofence:(CLRegion *)geofence
{
    [self.insideGeofenceIds addObject:geofence.identifier];
}

- (void)geofenceManager:(QKGeofenceManager *)geofenceManager didExitGeofence:(CLRegion *)geofence
{
    [self.insideGeofenceIds removeObject:geofence.identifier];
    [self.tableView reloadData];
}

- (void)geofenceManager:(QKGeofenceManager *)geofenceManager didChangeState:(QKGeofenceManagerState)state
{
    if (state == QKGeofenceManagerStateProcessing) {
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [activityView startAnimating];
        UIBarButtonItem *spinnerItem = [[UIBarButtonItem alloc] initWithCustomView:activityView];
        [self.rightBarButtonItems removeObjectAtIndex:0];
        [self.rightBarButtonItems insertObject:spinnerItem atIndex:0];
        self.navigationItem.rightBarButtonItems = self.rightBarButtonItems;
    }
    else {
        [self.tableView reloadData];
        UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadGeofences)];
        [self.rightBarButtonItems removeObjectAtIndex:0];
        [self.rightBarButtonItems insertObject:refreshButton atIndex:0];
        self.navigationItem.rightBarButtonItems = self.rightBarButtonItems;
    }
}

- (void)geofenceManager:(QKGeofenceManager *)geofenceManager didFailWithError:(NSError *)error
{
    NSString *msg = [error localizedDescription];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];

}
#pragma mark - Location Manager

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [self.locationManager stopUpdatingLocation];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        NSError *error = nil;
        if (![context save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }   
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSManagedObject *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        [[segue destinationViewController] setGeofence:object];
    }
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Geofence" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Master"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSNumber *radius = [object valueForKey:@"radius"];
    NSString *identifier = [object valueForKey:@"identifier"];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (R=%@m)", identifier, radius];
    
    NSNumber *lat = [object valueForKey:@"lat"];
    NSNumber *lon = [object valueForKey:@"lon"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@, %@", lat, lon];
    
    if ([self.insideGeofenceIds containsObject:identifier]) {
        cell.backgroundColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:0.3];
    }
    else {
        cell.backgroundColor = nil;
    }
}

@end
