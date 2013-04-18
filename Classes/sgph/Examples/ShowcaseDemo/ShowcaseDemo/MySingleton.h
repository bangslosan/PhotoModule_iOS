#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "DataController.h"
#import "WorkOrder.h"
#import "Photo.h"
#import "PhotoLabel.h"


NSComparisonResult compareLabels(id t1, id t2, void* context);

//./build.py;unzip -o com.phmod-iphone-0.1.zip -d ~/Desktop/Safeguard

@class MySingleton;
extern MySingleton *gSingleton;

typedef enum
{
    PHFilterModeAll,
    PHFilterModeLabeled,
    PHFilterModeUnlabeled,
    PHFilterModeRequiredLabels
    
} PHFilterMode;


typedef enum
{
    PHASLabelFS,
    PHASViewfinder,
    PHASGrid,
    PHASExpanded
    
} PHAppState;

#pragma mark Duplicated Constants

typedef enum
{
    kStatusOpen = 2,
    kStatusRejected = 4,
    kStatusCompleted = 5,
    kStatusApproved = 6,
    kStatusWaitingForApproval = 13,
    kStatusFollowUp = 52,
    kStatusFollowUpRejected = 54,
    kStatusSubmitted = 105
} STATUS_ID;

typedef enum
{
    kStatusPhotoNotReady = 0,		// no photo is assigned to this label, or no label is assigned to this photo
    kStatusPhotoPendingOrder = 1,	// photo is ready, but waiting for the order to be sent
    kStatusPhotoReady = 2,			// Photo Ready to send
    kStatusPhotoUploaded = 3,		// Photo has been sent
    kStatusPhotoUploadFailed = 4    // Photo failed to send
} PHOTO_STATUS_ID;

#define UNLABELED_STRING	[NSString stringWithFormat:@"[No Label]"]

//work order status:
typedef enum
{
    kOrderStatusNotStarted = 0,		//0:Order Not Started
    kOrderStatusStarted = 1, 		//1:Order Started
    kOrderStatusComplete = 2, 		//2:Order Complete
    kOrderStatusSubmitted = 3, 		//3:Order Submitted
    kOrderStatusSubmitFailed = 4 	//4:Order Failed to Submit
} ORDER_STATUS_ID;

@interface MySingleton : NSObject
{
    //NSString *someProperty;
    BOOL _newPhotos;
    BOOL _expandOn;
    BOOL _editOn;
    BOOL _filterOn;
    BOOL _iPadDevice;
    BOOL _isModule;
    BOOL _doRef;
    BOOL _openToGallery;
    BOOL _applyCaptureDefaults;
    
    PHFilterMode _currentFilterMode;
    PHAppState _currentAppState;
    
    NSMutableArray* _mainData;
    NSMutableArray *_labelArr;
    NSMutableArray *_requiredLabelArr;
    NSMutableArray *_itemArray;
    NSArray *_hashVals;
    NSArray *_hashValsReq;
    NSArray *_curHashVals;
    PhotoLabel *_currentPhotoLabel;
    PhotoLabel *_preSelectedLabel;
    NSInteger _expandedViewIndex;
    NSInteger _photoCount;
    NSInteger _requiredCount;
    NSInteger _labeledCount;
    NSString* _userId;
    NSString* _orderNumber;
    NSString* _docDir;
    NSString* _dbPath;
    
    NSArray* _curLetArray;
}

//@property (nonatomic, retain) NSString *someProperty;
@property (nonatomic) BOOL newPhotos;
@property (nonatomic) BOOL expandOn;
@property (nonatomic) BOOL editOn;
@property (nonatomic) BOOL filterOn;
@property (nonatomic) BOOL iPadDevice;
@property (nonatomic) BOOL isModule;
@property (nonatomic) BOOL doRef;
@property (nonatomic) BOOL openToGallery;
@property (nonatomic) BOOL applyCaptureDefaults;
@property (nonatomic) BOOL showTrace;


@property (nonatomic) PHFilterMode currentFilterMode;
@property (nonatomic) PHAppState currentAppState;

@property (nonatomic) NSInteger expandedViewIndex;
@property (nonatomic) NSInteger photoCount;
@property (nonatomic) NSInteger requiredCount;
@property (nonatomic) NSInteger labeledCount;


@property (nonatomic, strong) NSArray* curLetArray;

@property (nonatomic, strong) NSMutableArray* mainData;
@property (nonatomic, strong) NSMutableArray *labelArr;
@property (nonatomic, strong) NSMutableArray *requiredLabelArr;

@property (nonatomic, strong) NSArray *curHashVals;
@property (nonatomic, strong) NSArray *hashVals;
@property (nonatomic, strong) NSArray *hashValsReq;

@property (nonatomic, strong) NSMutableArray *itemArray;

@property (nonatomic, strong) PhotoLabel *currentPhotoLabel;
@property (nonatomic, strong) NSString *currentLabelDescription;

@property (nonatomic, strong) NSString* dbPath;
@property (nonatomic, strong) DataController *dbController;
@property (nonatomic, strong) WorkOrder *workOrder;
@property (nonatomic, strong) NSString* orderNumber;
@property (nonatomic, strong) NSString* userId;
@property (nonatomic, strong) NSString* rootPhotoFolder;
@property (nonatomic, strong) NSString* todaysPhotoFolder;
@property (nonatomic, strong) NSString* docDir;
@property (nonatomic, strong) PhotoLabel* preSelectedLabel;

//+ (id)sharedSingleton;

- (NSString*) getDataDirFull;
- (NSString*) getDataDirRelative;
- (NSString*) getPhotoDirFull;
- (NSString*) getPhotoDirRelative;
- (NSString*) getThumbDirFull;
- (NSString*) getThumbDirRelative;

- (BOOL) isReqLab:(NSString*)testLabel;
- (void) updateLabelHash;

- (void)delImage:(Photo *)photo;
- (void)saveImage:(UIImage *)image withName:(NSString *)name andMetaData:(NSDictionary *)metadata;
//- (void)renameImage:(NSString *)oldName withName:(NSString *)newName;

- (id)init:(BOOL)isAppModule;
- (void) writeToLog:(NSString *)format, ...;
- (void) setDBName:(NSString *)dbName;
- (void) setTrace:(BOOL)traceOn;
- (void) parseLabels:(NSString*)newLabels;
//- (void) setReqLabels;
- (void) parsePreSelectedLabel:(NSString*)newLabel;
- (void) setOrderNum:(NSString *)orderNum;
- (void) setRootPhotoFolder:(NSString *)aFolder;
- (void) setTodaysPhotoFolder:(NSString *)aFolder;
- (void) setReqCount:(NSString *)newCount;
- (void) setHashReq:(BOOL)isReq;
- (void) unselectAll;
- (void)setPhotoLabelFromDisplayText:(NSString *)displayText;

@end
