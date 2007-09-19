#import "TBinaryProtocol.h"
#import "TProtocolException.h"

int32_t VERSION_1 = 0x80010000;
int32_t VERSION_MASK = 0xffff0000;


@implementation TBinaryProtocol

- (id) initWithTransport: (id <TTransport>) transport
{
  return [self initWithTransport: transport strictRead: NO strictWrite: NO];
}

- (id) initWithTransport: (id <TTransport>) transport 
              strictRead: (BOOL) strictRead
             strictWrite: (BOOL) strictWrite
{
  self = [super init];
  mTransport = [transport retain];
  mStrictRead = strictRead;
  mStrictWrite = strictWrite;
  return self;
}


- (void) dealloc
{
  [mTransport release];
  [super dealloc];
}


- (id <TTransport>) transport
{
  return mTransport;
}


- (NSString *) readStringBody: (int) size
{
  char buff[size+1];
  [mTransport readAll: (uint8_t *) buff offset: 0 length: size];
  buff[size] = 0;
  return [NSString stringWithUTF8String: buff];
}


- (void) readMessageBeginReturningName: (NSString **) name
                                  type: (int *) type
                            sequenceID: (int *) sequenceID
{
  int size = [self readI32];
  if (size < 0) {
    int version = size & VERSION_MASK;
    if (version != VERSION_1) {
      @throw [TProtocolException exceptionWithName: @"Bad version in readMessageBegin"];
    }
    if (type != NULL) {
      *type = version & 0x00FF;
    }
    NSString * messageName = [self readString];
    if (name != NULL) {
      *name = messageName;
    }
    int seqID = [self readI32];
    if (sequenceID != NULL) {
      *sequenceID = seqID;
    }
  } else {
    if (mStrictRead) {
      @throw [TProtocolException exceptionWithName: @"Missing version in readMessageBegin, old client?"];
    }
    NSString * messageName = [self readStringBody: size];
    if (name != NULL) {
      *name = messageName;
    }
    int messageType = [self readByte];
    if (type != NULL) {
      *type = messageType;
    }
    int seqID = [self readI32];
    if (sequenceID != NULL) {
      *sequenceID = seqID;
    }
  }
}


- (void) readMessageEnd {}


- (void) readStructBeginReturningName: (NSString **) name
{
  if (name != NULL) {
    *name = nil;
  }
}


- (void) readStructEnd {}


- (void) readFieldBeginReturningName: (NSString **) name
                                type: (int *) fieldType
                             fieldID: (int *) fieldID
{
  if (name != NULL) {
    *name = nil;
  }
  int ft = [self readByte];
  if (fieldType != NULL) {
    *fieldType = ft;
  }    
  if (ft != TType_STOP) {
    int fid = [self readI16];
    if (fieldID != NULL) {
      *fieldID = fid;
    }
  }
}


- (void) readFieldEnd {}


- (int32_t) readI32
{
  uint8_t i32rd[4];
  [mTransport readAll: i32rd offset: 0 length: 4];
  return
    ((i32rd[0] & 0xff) << 24) |
    ((i32rd[1] & 0xff) << 16) |
    ((i32rd[2] & 0xff) <<  8) |
    ((i32rd[3] & 0xff));
}


- (NSString *) readString
{
  int size = [self readI32];
  return [self readStringBody: size];
}


- (BOOL) readBool
{
  return [self readByte] == 1;
}

- (uint8_t) readByte
{
  uint8_t myByte;
  [mTransport readAll: &myByte offset: 0 length: 1];
  return myByte;
}

- (short) readI16
{
  uint8_t buff[2];
  [mTransport readAll: buff offset: 0 length: 2];
  return (short)
    (((buff[0] & 0xff) << 8) |
     ((buff[1] & 0xff)));
  return 0;
}

- (int64_t) readI64;
{
  uint8_t i64rd[8];
  [mTransport readAll: i64rd offset: 0 length: 8];
  return
    ((int64_t)(i64rd[0] & 0xff) << 56) |
    ((int64_t)(i64rd[1] & 0xff) << 48) |
    ((int64_t)(i64rd[2] & 0xff) << 40) |
    ((int64_t)(i64rd[3] & 0xff) << 32) |
    ((int64_t)(i64rd[4] & 0xff) << 24) |
    ((int64_t)(i64rd[5] & 0xff) << 16) |
    ((int64_t)(i64rd[6] & 0xff) <<  8) |
    ((int64_t)(i64rd[7] & 0xff));
}

- (double) readDouble;
{
  // FIXME - will this get us into trouble on PowerPC?
  int64_t ieee754 = [self readI64];
  return *((double *) &ieee754);
}


- (NSData *) readBinary
{
  int32_t size = [self readI32];
  uint8_t * buff = malloc(size);
  if (buff == NULL) {
    @throw [TProtocolException 
             exceptionWithName: @"Out of memory" 
             reason: [NSString stringWithFormat: @"Unable to allocate %d bytes trying to read binary data.",
                               size]];
  }
  [mTransport readAll: buff offset: 0 length: size];
  return [NSData dataWithBytesNoCopy: buff length: size];
}


- (void) readMapBeginReturningKeyType: (int *) keyType
                            valueType: (int *) valueType
                                 size: (int *) size
{
  int kt = [self readByte];
  int vt = [self readByte];
  int s = [self readI32];
  if (keyType != NULL) {
    *keyType = kt;
  }
  if (valueType != NULL) {
    *valueType = vt;
  }
  if (size != NULL) {
    *size = s;
  }
}

- (void) readMapEnd {}


- (void) readSetBeginReturningElementType: (int *) elementType
                                     size: (int *) size
{
  int et = [self readByte];
  int s = [self readI32];
  if (elementType != NULL) {
    *elementType = et;
  }
  if (size != NULL) {
    *size = s;
  }
}


- (void) readSetEnd {}


- (void) readListBeginReturningElementType: (int *) elementType
                                      size: (int *) size
{
  int et = [self readByte];
  int s = [self readI32];
  if (elementType != NULL) {
    *elementType = et;
  }
  if (size != NULL) {
    *size = s;
  }
}


- (void) readListEnd {}


- (void) writeByte: (uint8_t) value
{
  [mTransport write: &value offset: 0 length: 1];
}


- (void) writeMessageBeginWithName: (NSString *) name
                              type: (int) messageType
                        sequenceID: (int) sequenceID
{
  if (mStrictWrite) {
    int version = VERSION_1 | messageType;
    [self writeI32: version];
    [self writeString: name];
    [self writeI32: sequenceID];
  } else {
    [self writeString: name];
    [self writeByte: messageType];
    [self writeI32: sequenceID];
  }
}


- (void) writeMessageEnd {}


- (void) writeStructBeginWithName: (NSString *) name {}


- (void) writeStructEnd {}


- (void) writeFieldBeginWithName: (NSString *) name
                            type: (int) fieldType
                         fieldID: (int) fieldID
{
  [self writeByte: fieldType];
  [self writeI16: fieldID];
}


- (void) writeI32: (int32_t) value
{
  uint8_t buff[4];
  buff[0] = 0xFF & (value >> 24);
  buff[1] = 0xFF & (value >> 16);
  buff[2] = 0xFF & (value >> 8);
  buff[3] = 0xFF & value;
  [mTransport write: buff offset: 0 length: 4];
}

- (void) writeI16: (short) value
{
  uint8_t buff[2];
  buff[0] = 0xff & (value >> 8);
  buff[1] = 0xff & value;
  [mTransport write: buff offset: 0 length: 2];
}


- (void) writeI64: (int64_t) value
{
  uint8_t buff[8];
  buff[0] = 0xFF & (value >> 56);
  buff[1] = 0xFF & (value >> 48);
  buff[2] = 0xFF & (value >> 40);
  buff[3] = 0xFF & (value >> 32);
  buff[4] = 0xFF & (value >> 24);
  buff[5] = 0xFF & (value >> 16);
  buff[6] = 0xFF & (value >> 8);
  buff[7] = 0xFF & value;
  [mTransport write: buff offset: 0 length: 8];
}

- (void) writeDouble: (double) value
{
  // spit out IEEE 754 bits - FIXME - will this get us in trouble on
  // PowerPC?
  [self writeI64: *((int64_t *) &value)];
}


- (void) writeString: (NSString *) value
{
  if (value != nil) {
    const char * utf8Bytes = [value UTF8String];
    size_t length = strlen(utf8Bytes);
    [self writeI32: length];
    [mTransport write: (uint8_t *) utf8Bytes offset: 0 length: length];
  } else {
    // instead of crashing when we get null, let's write out a zero length string
    [self writeI32: 0];
  }
}


- (void) writeBinary: (NSData *) data 
{
  [self writeI32: [data length]];
  [mTransport write: [data bytes] offset: 0 length: [data length]];
}

- (void) writeFieldStop
{
  [self writeByte: TType_STOP];
}


- (void) writeFieldEnd {}


- (void) writeMapBeginWithKeyType: (int) keyType
                        valueType: (int) valueType
                             size: (int) size
{
  [self writeByte: keyType];
  [self writeByte: valueType];
  [self writeI32: size];
}

- (void) writeMapEnd {}


- (void) writeSetBeginWithElementType: (int) elementType
                                 size: (int) size
{
  [self writeByte: elementType];
  [self writeI32: size];
}

- (void) writeSetEnd {}


- (void) writeListBeginWithElementType: (int) elementType
                                  size: (int) size
{
  [self writeByte: elementType];
  [self writeI32: size];
}

- (void) writeListEnd {}


- (void) writeBool: (BOOL) value
{
  [self writeByte: (value ? 1 : 0)];
}

@end
