#!/usr/bin/env python3
"""Minimal Android binary XML (AXML) reader.

Enough of the format to answer one question about an APK: which package is it,
and which service is its input method. Avoids needing aapt2 or the Android SDK.
"""
import struct, sys, zipfile

RES_STRING_POOL = 0x0001
RES_XML_START   = 0x0102
RES_XML_END     = 0x0103
RES_XML_RESMAP  = 0x0180
ATTR_NAME_RESID = 0x01010003          # android:name


def _strings(buf, off):
    """Decode a RES_STRING_POOL chunk at off -> list[str]."""
    _type, hdr_size, size = struct.unpack_from('<HHI', buf, off)
    count, _styles, flags, str_start, _sty_start = struct.unpack_from('<IIIII', buf, off + 8)
    utf8 = bool(flags & (1 << 8))
    offs = struct.unpack_from('<%dI' % count, buf, off + hdr_size)
    base = off + str_start
    out = []
    for o in offs:
        p = base + o
        try:
            if utf8:
                # two length fields (utf16 len, then utf8 byte len), each 1-2 bytes
                n = buf[p]; p += 2 if n & 0x80 else 1
                n = buf[p]
                if n & 0x80:
                    n = ((n & 0x7F) << 8) | buf[p + 1]; p += 2
                else:
                    p += 1
                out.append(buf[p:p + n].decode('utf-8', 'replace'))
            else:
                n = struct.unpack_from('<H', buf, p)[0]; p += 2
                if n & 0x8000:
                    n = ((n & 0x7FFF) << 16) | struct.unpack_from('<H', buf, p)[0]; p += 2
                out.append(buf[p:p + n * 2].decode('utf-16-le', 'replace'))
        except Exception:
            out.append('')
    return out


def parse(data):
    """-> (package, [service class names that declare android.view.InputMethod])"""
    pool, resmap = [], []
    off, end = 8, len(data)
    # chunk walk
    while off + 8 <= end:
        ctype, hdr, size = struct.unpack_from('<HHI', data, off)
        if size <= 0:
            break
        if ctype == RES_STRING_POOL:
            pool = _strings(data, off)
        elif ctype == RES_XML_RESMAP:
            n = (size - hdr) // 4
            resmap = list(struct.unpack_from('<%dI' % n, data, off + hdr))
        off += size

    def s(i):
        return pool[i] if 0 <= i < len(pool) else ''

    package, imes = None, []
    stack, svc_stack = [], []
    off = 8
    while off + 8 <= end:
        ctype, hdr, size = struct.unpack_from('<HHI', data, off)
        if size <= 0:
            break
        if ctype == RES_XML_START:
            name = s(struct.unpack_from('<I', data, off + hdr + 4)[0])
            acount = struct.unpack_from('<H', data, off + hdr + 12)[0]
            astart = off + hdr + struct.unpack_from('<H', data, off + hdr + 8)[0]
            attrs = {}
            for i in range(acount):
                a = astart + i * 20
                ns_i, nm_i, raw_i = struct.unpack_from('<III', data, a)
                dtype, dval = struct.unpack_from('<BI', data, a + 15)[0], struct.unpack_from('<I', data, a + 16)[0]
                key = s(nm_i)
                if not key and nm_i < len(resmap) and resmap[nm_i] == ATTR_NAME_RESID:
                    key = 'name'
                val = s(raw_i) if raw_i != 0xFFFFFFFF else (s(dval) if dtype == 0x03 else str(dval))
                attrs[key] = val
            stack.append(name)
            if name == 'manifest':
                package = attrs.get('package') or package
            elif name == 'service':
                svc_stack.append([attrs.get('name', ''), False])
            elif name == 'action' and svc_stack:
                if attrs.get('name') == 'android.view.InputMethod':
                    svc_stack[-1][1] = True
        elif ctype == RES_XML_END:
            name = s(struct.unpack_from('<I', data, off + hdr + 4)[0])
            if stack:
                stack.pop()
            if name == 'service' and svc_stack:
                cls, is_ime = svc_stack.pop()
                if is_ime:
                    imes.append(cls)
        off += size
    return package, imes


def from_apk(path):
    with zipfile.ZipFile(path) as z:
        return parse(z.read('AndroidManifest.xml'))


if __name__ == '__main__':
    pkg, imes = from_apk(sys.argv[1])
    print('package :', pkg)
    for c in imes:
        full = pkg + c if c.startswith('.') else c
        print('ime     :', f'{pkg}/{full}')
