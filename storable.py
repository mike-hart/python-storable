
#
# License
#
# python storable is distributed under the zlib/libpng license, which is OSS
# (Open Source Software) compliant.
#
# Copyright (C) 2009 Tim Aerts
#
# This software is provided 'as-is', without any express or implied
# warranty.  In no event will the authors be held liable for any damages
# arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
#
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#
# Tim Aerts <aardbeiplantje@gmail.com>
#

from struct import unpack
import cStringIO

def SX_OBJECT(fh, cache, parent):
    i = unpack('!I', fh.read(4))[0]
    cache['has_sx_object'] = True
    return (0, i)

def SX_LSCALAR(fh, cache, parent):
    size = unpack('!I', fh.read(4))[0]
    return fh.read(size)

def SX_LUTF8STR(fh, cache, parent):
    return SX_LSCALAR(fh, cache)

def SX_ARRAY(fh, cache, parent):
    size = unpack('!I', fh.read(4))[0]
    data = []
    for i in range(0,size):
        data.append(process_item(fh, cache, data))

    return data

def SX_HASH(fh, cache, parent):
    size = unpack('!I', fh.read(4))[0]
    data = {}
    for i in range(0,size):
        value = process_item(fh, cache, data)
        size  = unpack('!I', fh.read(4))[0]
        key   = fh.read(size)
        data[key] = value

    return data

def SX_REF(fh, cache, parent):
    return process_item(fh, cache, parent)

def SX_UNDEF(fh, cache, parent):
    return None

def SX_DOUBLE(fh, cache, parent):
    return unpack('d', fh.read(8))[0]

def SX_BYTE(fh, cache, parent):
    return unpack('B', fh.read(1))[0] - 128

def SX_SCALAR(fh, cache, parent):
    size = unpack('B', fh.read(1))[0]
    return fh.read(size)

def SX_UTF8STR(fh, cache, parent):
    return SX_SCALAR(fh, cache, parent)

def SX_TIED_ARRAY(fh, cache, parent):
    return process_item(fh, cache, parent)

def SX_TIED_HASH(fh, cache, parent):
    return SX_TIED_ARRAY(fh, cache, parent)

def SX_TIED_SCALAR(fh, cache, parent):
    return SX_TIED_ARRAY(fh, cache, parent)

def SX_SV_UNDEF(fh, cache, parent):
    return None

def SX_BLESS(fh, cache, parent):
    size = unpack('B', fh.read(1))[0]
    package_name = fh.read(size)
    cache['classes'].append(package_name)
    return process_item(fh, cache, parent)

def SX_IX_BLESS(fh, cache, parent):
    indx = unpack('B', fh.read(1))[0]
    package_name = cache['classes'][indx]
    return process_item(fh, cache, parent)

def SX_OVERLOAD(fh, cache, parent):
    return process_item(fh, cache, parent)

def SX_TIED_KEY(fh, cache, parent):
    data = process_item(fh, cache, parent)
    key  = process_item(fh, cache, parent)
    return data
    
def SX_TIED_IDX(fh, cache, parent):
    data = process_item(fh, cache, parent)
    indx_in_array = unpack('i', fh.read(4))[0]
    return data

# *AFTER* all the subroutines
engine = {
    '\x00': SX_OBJECT,      # ( 0): Already stored object
    '\x01': SX_LSCALAR,     # ( 1): Scalar (large binary) follows (length, data)
    '\x02': SX_ARRAY,       # ( 2): Array forthcoming (size, item list)
    '\x03': SX_HASH,        # ( 3): Hash forthcoming (size, key/value pair list)
    '\x04': SX_REF,         # ( 4): Reference to object forthcoming
    '\x05': SX_UNDEF,       # ( 5): Undefined scalar
    '\x07': SX_DOUBLE,      # ( 7): Double forthcoming
    '\x08': SX_BYTE,        # ( 8): (signed) byte forthcoming
    '\x0a': SX_SCALAR,      # (10): Scalar (binary, small) follows (length, data)
    '\x0b': SX_TIED_ARRAY,  # (11): Tied array forthcoming
    '\x0c': SX_TIED_HASH,   # (12): Tied hash forthcoming
    '\x0d': SX_TIED_SCALAR, # (13): Tied scalar forthcoming
    '\x0e': SX_SV_UNDEF,    # (14): Perl's immortal PL_sv_undef
    '\x11': SX_BLESS,       # (17): Object is blessed
    '\x12': SX_IX_BLESS,    # (18): Object is blessed, classname given by index
    '\x14': SX_OVERLOAD,    # (20): Overloaded reference
    '\x15': SX_TIED_KEY,    # (21): Tied magic key forthcoming
    '\x16': SX_TIED_IDX,    # (22): Tied magic index forthcoming
    '\x17': SX_UTF8STR,     # (23): UTF-8 string forthcoming (small)
    '\x18': SX_LUTF8STR,    # (24): UTF-8 string forthcoming (large)
}

def handle_sx_object_refs(cache, data):
    iterateelements = None
    if type(data) is list:
        iterateelements = enumerate(iter(data))
    elif type(data) is dict:
        iterateelements = data.iteritems()
    else:
        return
    
    for k,item in iterateelements:
        if type(item) is list or type(item) is dict:
            handle_sx_object_refs(cache, item)
        if type(item) is tuple:
            data[k] = cache['objects'][item[1]]
    return data

def process_item(fh, cache, parent=None):
    data = None
    magic_type = fh.read(1)
    if magic_type in engine:
        #print(engine[magic_type])
        i = None
        if magic_type not in ['\x00', '\x0b', '\x0c', '\x0d']:
            cache['objects'].append(data)
            i = len(cache['objects']) - 1
        data = engine[magic_type](fh, cache, parent)

        if i is not None:
            cache['objects'][i] = data

    #print(cache)
    return data

def thaw(frozen_data):
    fh    = cStringIO.StringIO(frozen_data)
    magic = fh.read(2)
    if magic == '\x05\x07':
        #print("OK:nfreeze") 
        pass
    if magic == '\x04\x07':
        magic = fh.read(9)
        if magic == '\x04\x34\x33\x32\x31\x04\x04\x04\x08':
            #print("OK:freeze") 
            pass

    cache = { 'objects' : [], 'classes' : [], 'has_sx_object' : False }
    data = process_item(fh, cache)

    if cache['has_sx_object']:
        handle_sx_object_refs(cache, data)
    
    return data

