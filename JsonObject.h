//
//  JsonObject.h
//  campustch
//
//  Created by Feng Stone on 3/22/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol JsonSerialization <NSObject>

@required
- (id)serializedObject;

@end

@class JsonObject;
@interface NSUserDefaults (jsonObject)

/**
    Unarchive data from NSUserDefaults
    @Parameter: key - The key to retrieve data from NSUserDefaults
    @Parameter: decoder - The class for unarchive data
 */
- (__kindof JsonObject *_Nullable)jsonObjectForKey:(NSString *)key decoder:(Class)decoder;

/**
    Archive An Object, which inherits from JsonObject, to the NSUserDefaults.
    @Parameter: object - The Object to be archived, shall inherit from JsonObject
    @Parameter: key - The key to identify the archived object in NSUserDefaults.
 */
- (void)setJsonObject:(JsonObject *)object forKey:(NSString *)key;

@end

@interface NSArray (jsonObject) <JsonSerialization>

/**
    Convert a json list to a list of object.
    @Parameter: serializedObjects - json list
    @Parameter: decoder - What class are these json objects converting to.
 */
+ (NSArray *_Nullable)arrayWithSerializedObjects:(NSArray<NSDictionary *> *)serializedObjects decoder:(Class)decoder;

/**
    Serialize all of the contents of this array.
 */
- (NSArray *)serializedObject;

@end

@interface NSDictionary (jsonObject) <JsonSerialization>

/**
    Serialize all of the contents of this dictionary.
 */
- (NSDictionary *)serializedObject;

@end

@interface JsonObject : NSObject <NSCopying, NSCoding, JsonSerialization>

/**
    If the property name and Json key don't match, this rename Dictionary for pairing them.
 */
@property (nonatomic, strong, class, nullable) NSDictionary<NSString *, NSString *> *rename;    // @"json key" : @"property name"

/**
    The property names in ignore will be ignored while serializing.
 */
@property (nonatomic, strong, class, nullable) NSArray<NSString *> *ignore;                     // @"property name", ignored when serializing.

/**
    If the property is a JsonObject, then its Class has to be declared.
 */
@property (nonatomic, strong, class, nullable) NSDictionary<NSString *, Class> *decoders;       // Use for decode NSArray items;

+ (NSString *)propertyNameWithKey:(NSString *)key;
+ (NSString *)keyWithPropertyName:(NSString *)name;
+ (BOOL)isIgnoredPropertyName:(NSString *)name;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary NS_REQUIRES_SUPER;

- (NSDictionary *)serializedObject;

- (void)decodeListWithKey:(NSString *)key value:(id)value;

// Serialize a JsonObject and save the data onto the filePath.
- (NSInteger)serializeToFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error;
+ (NSInteger)write:(id<JsonSerialization>)serializableObject toFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error;

// Load the serialized data from the file at filePath,
// and convert the data to a JsonObject.
- (instancetype)initWithContentOfFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error;
+ (id _Nullable)serializedObjectWithContentOfFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error;

@end

NS_ASSUME_NONNULL_END
