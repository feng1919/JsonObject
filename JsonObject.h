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

- (__kindof JsonObject *_Nullable)jsonObjectForKey:(NSString *)key decoder:(Class)decoder;
- (void)setJsonObject:(JsonObject *)object forKey:(NSString *)key;

@end

@interface NSArray (jsonObject) <JsonSerialization>

+ (NSArray *_Nullable)arrayWithSerializedObjects:(NSArray<NSDictionary *> *)serializedObjects decoder:(Class)decoder;
- (NSArray *)serializedObject;

@end

@interface NSDictionary (jsonObject) <JsonSerialization>

- (NSDictionary *)serializedObject;

@end

@interface JsonObject : NSObject <NSCopying, NSCoding, JsonSerialization>

@property (nonatomic, strong, class, nullable) NSDictionary<NSString *, NSString *> *rename;    // @"server key" : @"property name"
@property (nonatomic, strong, class, nullable) NSArray<NSString *> *ignore;                     // @"property name", ignored when serializing.
@property (nonatomic, strong, class, nullable) NSDictionary<NSString *, Class> *decoders;       // Use for decode NSArray items;

+ (NSString *)propertyNameWithKey:(NSString *)key;
+ (NSString *)keyWithPropertyName:(NSString *)name;
+ (BOOL)isIgnoredPropertyName:(NSString *)name;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary NS_REQUIRES_SUPER;

- (NSDictionary *)serializedObject;

- (void)decodeListWithKey:(NSString *)key value:(id)value;

// Serialize a JsonObject and save the data onto the filePath.
- (NSInteger)serializeToFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error;
- (NSInteger)serializeToFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error encrypted:(BOOL)encrypted;

+ (NSInteger)write:(id<JsonSerialization>)serializableObject toFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error;
+ (NSInteger)write:(id<JsonSerialization>)serializableObject toFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error encrypted:(BOOL)encrypted;

// Load the serialized data from the file at filePath,
// and convert the data to a JsonObject.
- (instancetype)initWithContentOfFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error;
- (instancetype)initWithContentOfFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error encrypted:(BOOL)encrypted;

+ (id _Nullable)serializedObjectWithContentOfFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error;
+ (id _Nullable)serializedObjectWithContentOfFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error encrypted:(BOOL)encrypted;

@end

NS_ASSUME_NONNULL_END
