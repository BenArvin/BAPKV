#!/usr/bin/python
# -*- coding: UTF-8 -*-

import sys, os, argparse, ctypes, binascii

BLOCK_SECTION_FULLLEN_LEN = 8
BLOCK_SECTION_KEYLEN_LEN = 4

def big_small_end_convert(data):
    return binascii.hexlify(binascii.unhexlify(data)[::-1])

class ValueFileDebugger(object):
    def __init__(self):
        super(ValueFileDebugger, self).__init__()

    def analyze(self, path=None, findMode=False, key=None):
        if path == None or len(path) == 0:
            print("Invalid path: None")
            return
        if os.path.exists(path) == False or os.path.isdir(path) == True:
            print("Invalid path: " + str(path))
            return
        if findMode == True and (key == None or len(key) == 0):
            print("Invalid key: " + str(key))
            return
        fp = open(path, 'rb')
        if fp == None:
            print("Open file failed")
            return
        if findMode == False:
            print("index\t\tfullLen\t\tkeyLen\t\tkey")
        fileSize = os.path.getsize(path)
        offset = 0
        finded = False
        offsetForFind = 0
        fullLenForFind = 0
        keyLenForFind = 0
        valueForFind = None
        while True:
            if offset >= fileSize:
                break
            fp.seek(offset)
            fullLenBytes = fp.read(BLOCK_SECTION_FULLLEN_LEN)
            fullLenInt = int.from_bytes(fullLenBytes, byteorder='little', signed=False)
            
            fp.seek(offset + BLOCK_SECTION_FULLLEN_LEN)
            keyLenBytes = fp.read(BLOCK_SECTION_KEYLEN_LEN)
            keyLenInt = int.from_bytes(keyLenBytes, byteorder='little', signed=False)

            fp.seek(offset + BLOCK_SECTION_FULLLEN_LEN + BLOCK_SECTION_KEYLEN_LEN)
            keyBytes = fp.read(keyLenInt)
            keyStr = bytes.decode(keyBytes)
            
            if findMode == False:
                print(str(offset) + "\t\t" + str(fullLenInt) + "\t\t" + str(keyLenInt) + "\t\t" + str(keyStr))
            else:
                if keyStr == key:
                    finded = True
                    fp.seek(offset + BLOCK_SECTION_FULLLEN_LEN + BLOCK_SECTION_KEYLEN_LEN + keyLenInt)
                    valueBytes = fp.read(fullLenInt - BLOCK_SECTION_FULLLEN_LEN - BLOCK_SECTION_KEYLEN_LEN - keyLenInt)
                    offsetForFind = offset
                    fullLenForFind = fullLenInt
                    keyLenForFind = keyLenInt
                    valueForFind = bytes.decode(valueBytes)

            offset = offset + fullLenInt
        fp.close()

        if findMode == True:
            print("index: " + str(offsetForFind) + "\nfullLen: " + str(fullLenForFind) + "\nkeyLen: " + str(keyLenForFind) + "\nkey: " + str(key))
            if finded == False:
                print("Can't find value")
            else:
                print("value: " + str(valueForFind))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="python3 DataFileDebug.py --mode value")
    parser.add_argument("-m", "--mode", help="Mode of debug, value/v: analyze value file, findValue/fv: find the value of key, index/i: analyze index file")
    parser.add_argument("-p", "--path", help="Path of file need analyze")
    parser.add_argument("-k", "--key", help="Key of value you want to find")
    args = parser.parse_args()

    if args.mode == "value" or args.mode == "v":
        debugger = ValueFileDebugger()
        debugger.analyze(args.path)
    elif args.mode == "findValue" or args.mode == "fv":
        debugger = ValueFileDebugger()
        debugger.analyze(args.path, True, args.key)
    else:
        print("This mode not supported yet")