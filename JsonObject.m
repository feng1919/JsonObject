//
//  JsonObject.m
//  campustch
//
//  Created by Feng Stone on 3/22/21.
//

#import "JsonObject.h"
#include <objc/runtime.h>

@implementation NSUserDefaults (jsonObject)

- (JsonObject *_Nullable)jsonObjectForKey:(NSString *)key decoder:(Class)decoder {
    if (key.length == 0) {
        return nil;
    }
    NSData *data = [self objectForKey:key];
    if (data.length == 0) {
        return nil;
    }
    NSError *error = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        NSLog(@"%@", error.localizedDescription);
        return nil;
    }
    return [[decoder alloc] initWithDictionary:obj];
}

- (void)setJsonObject:(JsonObject *)object forKey:(NSString *)key {
    if (key.length == 0 || object == nil) {
        return;
    }
    NSDictionary *serializedObject = object.serializedObject;
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:serializedObject options:0 error:&error];
    if (error) {
        NSLog(@"%@", error.localizedDescription);
        return;
    }
    if (data.length == 0) {
        return;
    }
    [self setObject:data forKey:key];
}

@end

@implementation NSArray (jsonObject)

+ (instancetype)arrayWithSerializedObjects:(NSArray<NSDictionary *> *)serializedObjects decoder:(Class)decoder {
    if (![decoder isSubclassOfClass:[JsonObject class]]) {
        return nil;
    }
    
    if (![serializedObjects isKindOfClass:[NSArray class]]) {
        return nil;
    }
    
    NSMutableArray *array = [NSMutableArray array];
    for (id element in serializedObjects) {
        id obj = [[decoder alloc] initWithDictionary:element];
        if (obj) {
            [array addObject:obj];
        }
    }
    return [NSArray arrayWithArray:array];
}

- (NSArray *)serializedObject {
    
    NSMutableArray *array = [NSMutableArray array];
    for (id object in self) {
        if ([object respondsToSelector:@selector(serializedObject)]) {
            [array addObject:[object serializedObject]];
        }
        else {
            [array addObject:object];
        }
    }
    return [NSArray arrayWithArray:array];
}

@end

@implementation NSDictionary (jsonObject)

- (NSDictionary *)serializedObject {
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (id key in self.allKeys) {
        id object = self[key];
        if ([object respondsToSelector:@selector(serializedObject)]) {
            dictionary[key] = [object serializedObject];
        }
        else {
            dictionary[key] = object;
        }
    }
    return [NSDictionary dictionaryWithDictionary:dictionary];
}

@end

static NSMutableDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *RENAME = nil;
static NSMutableDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *UNRENAME = nil;
static NSMutableDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *IGNORE = nil;
static NSMutableDictionary<NSString *, NSDictionary<NSString *, Class> *> *DECODERS_MAP = nil;

@implementation JsonObject
@dynamic rename;
@dynamic ignore;
@dynamic decoders;

+ (void)initialize {
    if (self == [JsonObject class]) {
        RENAME = [NSMutableDictionary dictionary];
        UNRENAME = [NSMutableDictionary dictionary];
        self.rename = @{@"id":@"uid",
                        @"description":@"desc"
        };
        IGNORE = [NSMutableDictionary dictionary];
        DECODERS_MAP = [NSMutableDictionary dictionary];
    }
}

+ (void)setRename:(NSDictionary<NSString *, NSString *> *)rename {
    RENAME[NSStringFromClass(self)] = rename;
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (NSString *key in rename.allKeys) {
        NSString *propertyName = rename[key];
        dictionary[propertyName] = key;
    }
    UNRENAME[NSStringFromClass(self)] = [NSDictionary dictionaryWithDictionary:dictionary];
}

+ (NSDictionary<NSString *, NSString *> *)rename {
    return RENAME[NSStringFromClass(self)];
}

+ (void)setDecoders:(NSDictionary<NSString *,Class> *)decoders {
    DECODERS_MAP[NSStringFromClass(self)] = decoders;
}

+ (NSDictionary<NSString *,Class> *)decoders {
    return DECODERS_MAP[NSStringFromClass(self)];
}

+ (void)setIgnore:(NSArray<NSString *> *)ignore {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *key in ignore) {
        dict[key] = @(1);
    }
    IGNORE[NSStringFromClass(self)] = [NSDictionary dictionaryWithDictionary:dict];
}

+ (NSArray<NSString *> *)ignore {
    return [IGNORE[NSStringFromClass(self)] allKeys];
}

+ (BOOL)isIgnoredPropertyName:(NSString *)name {
    return IGNORE[NSStringFromClass(self)][name] != nil;
}

+ (NSString *)propertyNameWithKey:(NSString *)key {
    NSDictionary *map = RENAME[NSStringFromClass(self)];
    return map[key]?:key;
}

+ (NSString *)keyWithPropertyName:(NSString *)name {
    NSDictionary *map = UNRENAME[NSStringFromClass(self)];
    return map[name]?:name;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        Class cls = self.class;
        while ([cls isSubclassOfClass:[JsonObject class]]) {
            unsigned int outCount = 0;
            objc_property_t *property_list = class_copyPropertyList(cls, &outCount);
            for (int i = 0; i < outCount; i++) {
                objc_property_t property = property_list[i];
                NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
                id value = [coder decodeObjectForKey:propertyName];
                [self setValue:value forKey:propertyName];
            }
            free(property_list);
            
            cls = class_getSuperclass(cls);
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    Class cls = self.class;
    while ([cls isSubclassOfClass:[JsonObject class]]) {
        unsigned int outCount = 0;
        objc_property_t *property_list = class_copyPropertyList(cls, &outCount);
        for (int i = 0; i < outCount; i++) {
            objc_property_t property = property_list[i];
            NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
            id value = [self valueForKey:propertyName];
            if ([value respondsToSelector:@selector(serializedObject)]) {
                [coder encodeObject:[value serializedObject] forKey:propertyName];
            }
            else if (value != nil) {
                [coder encodeObject:value forKey:propertyName];
            }
        }
        free(property_list);
        cls = class_getSuperclass(cls);
    }
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if (self = [super init]) {
        NSMutableDictionary *renames = [NSMutableDictionary dictionary];
        NSMutableDictionary *ignores = [NSMutableDictionary dictionary];
        Class cls = self.class;
        while ([cls isSubclassOfClass:[JsonObject class]]) {
            [renames addEntriesFromDictionary:RENAME[NSStringFromClass(cls)]];
            [ignores addEntriesFromDictionary:IGNORE[NSStringFromClass(cls)]];
            cls = class_getSuperclass(cls);
        }
        
        NSArray<NSString *> *allKeys = dictionary.allKeys;
        for (NSString *key in allKeys) {
            NSString *name = renames[key]?:key;
            if (ignores[name] == nil) {
                [self setValue:dictionary[key] forKey:name];
            }
        }
    }
    return self;
}

- (NSDictionary *)serializedObject {
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    Class class = self.class;
    
    while ([class isSubclassOfClass:[JsonObject class]]) {
        unsigned int outCount = 0;
        objc_property_t *property_list = class_copyPropertyList(class, &outCount);
        for (int i = 0; i < outCount; i++) {
            objc_property_t property = property_list[i];
            NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
            if ([class isIgnoredPropertyName:propertyName]) {
                continue;
            }
            
            id value = [self valueForKey:propertyName];
            if ([value respondsToSelector:@selector(serializedObject)]) {
                [dictionary setObject:[value serializedObject] forKey:[class keyWithPropertyName:propertyName]];
            }
            else if (value != nil) {
                [dictionary setObject:value forKey:[class keyWithPropertyName:propertyName]];
            }
        }
        free(property_list);
        
        class = class_getSuperclass(class);
    }
    
    return dictionary;
}

- (id)copy {
    Class class = self.class;
    id object = [[class alloc] init];
    
    while ([class isSubclassOfClass:[JsonObject class]]) {
        unsigned int outCount = 0;
        objc_property_t *property_list = class_copyPropertyList(class, &outCount);
        for (int i = 0; i < outCount; i++) {
            objc_property_t property = property_list[i];
            NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
            id value = [self valueForKey:propertyName];
            [object setValue:value forKey:propertyName];
        }
        free(property_list);
        
        class = class_getSuperclass(class);
    }
    
    return object;
}

- (id)copyWithZone:(NSZone *)zone {
    Class class = self.class;
    id object = [[class allocWithZone:zone] init];
    
    while ([class isSubclassOfClass:[JsonObject class]]) {
        unsigned int outCount = 0;
        objc_property_t *property_list = class_copyPropertyList(class, &outCount);
        for (int i = 0; i < outCount; i++) {
            objc_property_t property = property_list[i];
            NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
            id value = [self valueForKey:propertyName];
            [object setValue:value forKey:propertyName];
        }
        free(property_list);
        
        class = class_getSuperclass(class);
    }
    
    return object;
}

- (NSString *)description {
    return [self serializedObject].description;
}

- (NSString *)debugDescription {
    return [self serializedObject].description;
}

- (void)decodeListWithKey:(NSString *)key value:(id)value {
    
    NSArray *list = value;
    NSMutableArray *array = nil;
    
    Class decoder = self.class.decoders[key];
    if (![decoder isSubclassOfClass:[JsonObject class]]) {
        goto FAILED_TO_DECODE;
        return;
    }
    
    if ([list isKindOfClass:NSDictionary.class]) {
        [super setValue:[[decoder alloc] initWithDictionary:(NSDictionary *)list] forKey:key];
        return;
    }
    
    if (![list isKindOfClass:NSArray.class] || ![list.firstObject isKindOfClass:NSDictionary.class]) {
        goto FAILED_TO_DECODE;
        return;
    }
    
    array = [NSMutableArray arrayWithCapacity:list.count];
    for (int i = 0; i < list.count; i++) {
        NSDictionary *dict = (NSDictionary *)list[i];
        [array addObject:[[decoder alloc] initWithDictionary:dict]];
    }
    [super setValue:[NSArray arrayWithArray:array] forKey:key];
    return;
    
FAILED_TO_DECODE:
    [super setValue:value forKey:key];
}

#pragma mark - Save Memory Status

- (NSInteger)serializeToFile:(NSString *)filePath error:(NSError *_Nullable*_Nullable)error {
    return [JsonObject write:self toFile:filePath error:error];
}

+ (NSInteger)write:(id<JsonSerialization>)serializableObject toFile:(NSString *)filePath error:(NSError *__autoreleasing  _Nullable *)error {
    id serializedObject = [serializableObject serializedObject];
    if (!serializedObject) {
        return 0;
    }
    
    NSError *error1 = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:serializedObject options:0 error:&error1];
    if (error1) {
        if (error != NULL) {
            *error = error1;
        }
        return 0;
    }
    
    if (data.length == 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                         code:-10875
                                     userInfo:@{NSLocalizedDescriptionKey:@"File does not exist or is empty."}];
        }
        return 0;
    }
    
    BOOL result = [data writeToFile:filePath options:NSDataWritingAtomic error:&error1];
    if (error1) {
        if (error != NULL) {
            *error = error1;
        }
        return 0;
    }
    if (!result) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                         code:-36
                                     userInfo:@{NSLocalizedDescriptionKey:@"I/O Failure."}];
        }
        return 0;
    }
    return data.length;
}

#pragma mark - Restore Memory Status

- (instancetype)initWithContentOfFile:(NSString *)filePath error:(NSError * _Nullable __autoreleasing *)error {
    NSError *error1 = nil;
    id serializedObject = [JsonObject serializedObjectWithContentOfFile:filePath error:&error1];
    if (error1) {
        if (error != NULL) {
            *error = error1;
        }
        return nil;
    }
    if (!serializedObject) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                         code:-10875
                                     userInfo:@{NSLocalizedDescriptionKey:@"File does not exist or is empty."}];
        }
        return nil;
    }
    if (![serializedObject isKindOfClass:[NSDictionary class]]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey:@"Failed to unarchive data."}];
        }
        return nil;
    }
    return [[self.class alloc] initWithDictionary:serializedObject];
}

+ (id _Nullable)serializedObjectWithContentOfFile:(NSString *)filePath error:(NSError **)error {
    if (filePath.length == 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                         code:-10875
                                     userInfo:@{NSLocalizedDescriptionKey:@"Invalid file path."}];
        }
        return nil;
    }
    
    NSError *error1 = nil;
    NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingUncached error:&error1];
    if (error1) {
        if (error != NULL) {
            *error = error1;
        }
        return nil;
    }
    
    if (data.length == 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                         code:-10875
                                     userInfo:@{NSLocalizedDescriptionKey:@"File does not exist or is empty."}];
        }
        return nil;
    }
    
    id serialzedObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error1];
    if (error1) {
        if (error != NULL) {
            *error = error1;
        }
        return nil;
    }
    return serialzedObject;
}

#pragma mark - KVC

- (void)setValue:(id)value forKey:(NSString *)key {
    
    if (key.length == 0) {
        return;
    }
    
    Class class = self.class;
    Ivar ivar = class_getInstanceVariable(class, [NSString stringWithFormat:@"_%@", key].UTF8String);
    if (ivar == NULL) {
#if __DEBUG__
        static NSArray *NSObjecctProtocolProperties = nil;
        if (NSObjecctProtocolProperties == nil) {
            NSObjecctProtocolProperties = @[@"hash", @"superclass", @"description", @"debugDescription"];
        }
        if (![NSObjecctProtocolProperties containsObject:key]) {
            NSLog(@"Property name missing: %@.%@ (%@)", NSStringFromClass(self.class) ,key, NSStringFromClass([(NSObject *)value class]));
        }
#endif
        return;
    }

    const char *type = ivar_getTypeEncoding(ivar);
    switch(type[0]) {
        case '@':
        {
            int length = 0;
            char *class_name = malloc(strlen(type)-1);
            for (int i = 1; i < strlen(type); i++) {
                if (type[i] != '\\' && type[i] != '"') {
                    class_name[length] = type[i];
                    length ++;
                }
            }
            class_name[length] = '\0';
            NSString *className = [NSString stringWithUTF8String:class_name];
            free(class_name);
            
            Class para_class = NSClassFromString(className);
            if ([para_class isSubclassOfClass:[JsonObject class]]) {
                if ([value isKindOfClass:[NSDictionary class]]) {
                    [super setValue:[[para_class alloc] initWithDictionary:value] forKey:key];
                }
                else {
                    NSLog(@"Unsurpported input value type: %@, expect NSDictionary.", NSStringFromClass([value class]));
                }
            }
            else if ([para_class isSubclassOfClass:NSArray.class]) {
                [self decodeListWithKey:key value:value];
            }
            else {
                [super setValue:value forKey:key];
            }
        }
            break;
        default:
            [super setValue:value forKey:key];
            break;
    }
}

- (id)valueForKey:(NSString *)key {
    
    if (key.length == 0) {
        return nil;
    }
    
    Class class = self.class;
    Ivar ivar = class_getInstanceVariable(class, [NSString stringWithFormat:@"_%@", key].UTF8String);
    if (ivar == NULL) {
        return nil;
    }
    
    return [super valueForKey:key];
}

//- (void)setValue:(id)value forProperty:(NSString *)propertyName {
//
//    Class class = self.class;
//    Ivar ivar = class_getClassVariable(class, propertyName.UTF8String);
//    if (ivar == NULL) {
//        return;
//    }
//
//    const char *type = ivar_getTypeEncoding(ivar);
//    switch(type[0]) {
//        case '@':
//        {
//            char *class_name = malloc(strlen(type)-1);
//            memcpy((void *)class_name, &type[1], strlen(type)-1);
//            NSString *className = [NSString stringWithUTF8String:class_name];
//            free(class_name);
//
//            if ([className isEqualToString:NSStringFromClass(NSString.class)]) {
////                NSString *setterName = [NSString stringWithFormat:@"set%@:", propertyName.capString];
////                SEL setter = NSSelectorFromString(setterName);
////                if (setter) {
////                    [self performSelector:setter withObject:value];
////                }
//                [self setValue:value forKey:propertyName];
//            }
//            else {
//
//            }
//            break;
//        }
//
//        case 'c':
//        {
//            char v = ((char (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%c", v];
//            break;
//        }
//
//        case 'i':
//        {
//            int v = ((int (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%i", v];
//            break;
//        }
//
//        case 's':
//        {
//            short v = ((short (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%d", v];
//            break;
//        }
//
//        case 'l':
//        {
//            long v = ((long (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%ld", v];
//            break;
//        }
//
//        case 'q':
//        {
//            long long v = ((long long (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%lld", v];
//            break;
//        }
//
//        case 'C':
//        {
//            unsigned char v = ((unsigned char (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%uc", v];
//            break;
//        }
//
//        case 'I':
//        {
//            unsigned int v = ((unsigned int (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%u", v];
//            break;
//        }
//
//        case 'S':
//        {
//            unsigned short v = ((unsigned short (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%u", v];
//            break;
//        }
//
//        case 'L':
//        {
//            unsigned long v = ((unsigned long (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%lu", v];
//            break;
//        }
//
//        case 'Q':
//        {
//            unsigned long long v = ((unsigned long long (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%llu", v];
//            break;
//        }
//
//        case 'f':
//        {
//            float v = ((float (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%f", v];
//            break;
//        }
//
//        case 'd':
//        {
//            double v = ((double (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%f", v];
//            break;
//        }
//
//        case 'B':
//        {
//            BOOL v = ((BOOL (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%@", v ? @"YES" : @"NO"];
//            break;
//        }
//
//        case '*':
//        {
//            char *v = ((char* (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"%s", v];
//            break;
//        }
//
//        case '#':
//        {
//            id v = object_getIvar(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"Class: %s", object_getClassName(v)];
//            break;
//        }
//
//        case ':':
//        {
//            SEL v = ((SEL (*)(id, Ivar))object_getIvar)(self, ivar);
//            valueDescription = [NSString stringWithFormat: @"Selector: %s", sel_getName(v)];
//            break;
//        }
//
//        case '[':
//        case '{':
//        case '(':
//        case 'b':
//        case '^':
//        {
//            valueDescription = [NSString stringWithFormat: @"%s", type];
//            break;
//        }
//
//        default:
//            valueDescription = [NSString stringWithFormat: @"UNKNOWN TYPE: %s", type];
//            break;
//    }
//}

@end
