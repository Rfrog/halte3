#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

#define dsTrue 0
#define dsFalse 1
#define dsUnknown 2
#define dsError 3
#define dsUnsupport 0xFF

#pragma pack(1)

typedef struct {
	wchar_t AName[0x500];
	unsigned int ANameLength;
	unsigned int AOffset;
	unsigned short AOrigin;
	unsigned int AStoreLength;
	unsigned int ARLength;
	unsigned int AHash[4];
	unsigned int ADate;
	unsigned int ATime;
	unsigned int AKey;
	unsigned int AKey2;
} TEntry; // PACKED RECORD

typedef struct {
	char magic[8]; /* "PACKDAT." */
	unsigned int dummy_index_entries;
	unsigned int index_entries;
} dat_header_t;

typedef struct {
	char name[32];
	unsigned int offset;
	unsigned int mode; /* BMP: 0x20000000 */
	unsigned int uncomprlen;
	unsigned int comprlen;
} dat_entry_t;

#pragma pack ()


wchar_t* _stdcall GetPluginName() {
	return L"VC6++Test";
}


void* _stdcall GetMemory(unsigned int Size) {
	return GlobalAlloc(GMEM_FIXED, Size);
}

unsigned int _stdcall FreeMemory(void* Memory) {
	GlobalFree(Memory);
	return 1;
}

unsigned int _stdcall GenerateEntries(unsigned int Input,
	TEntry** Output) {
	dat_header_t head;
	dat_entry_t* indexs;
	unsigned long size;
	unsigned int i;
	wchar_t Name[32];
	SetFilePointer((HANDLE)Input, 0, 0, FILE_BEGIN);
	ReadFile((HANDLE)Input, &head, sizeof(dat_header_t), &size, 0);
	indexs = (dat_entry_t *)GetMemory(head.index_entries*sizeof(dat_entry_t));
	size = head.index_entries*sizeof(dat_entry_t);
	ReadFile((HANDLE)Input, indexs, head.index_entries * sizeof(dat_entry_t),
		&size, 0);
	*Output = (TEntry *)GetMemory(head.index_entries*sizeof(TEntry));
	for (i = 0; i <head.index_entries; i++) {
		MultiByteToWideChar(CP_ACP, 0, indexs[i].name, -1, Name, 32);
		memcpy((*Output)[i].AName, Name, 32);
		(*Output)[i].AOffset = indexs[i].offset;
		(*Output)[i].AStoreLength = indexs[i].comprlen;
		(*Output)[i].ARLength = indexs[i].uncomprlen;
		(*Output)[i].AKey = indexs[i].mode;
		(*Output)[i].AOrigin = FILE_BEGIN;
	}
	FreeMemory(indexs);
	return head.index_entries;
}

unsigned int _stdcall ReadData(unsigned int Input,
	TEntry* Entry, void** Output) {
	unsigned long size;
	*Output = GetMemory(Entry->AStoreLength);
	SetFilePointer((HANDLE)Input, Entry->AOffset, 0, Entry->AOrigin);
	ReadFile((HANDLE)Input, *Output, Entry->AStoreLength, &size, 0);
	return size;
}

unsigned int _stdcall AutoDetect(unsigned int Input) {
	dat_header_t head;
	unsigned long size;
	SetFilePointer((HANDLE)Input, 0, 0, FILE_BEGIN);
	ReadFile((HANDLE)Input, &head, sizeof(dat_header_t), &size, 0);
	if (!strncmp(head.magic, "PACKDAT.", 8)) {
		return dsTrue;
	}
	return dsFalse;
}

unsigned int _stdcall PackProcessData(void* Input,
	TEntry* Entry, void** Output) {
	*Output = GetMemory(Entry->ARLength);
	memcpy(*Output, Input, Entry->ARLength);
	Entry->AStoreLength = Entry->ARLength;
	return Entry->AStoreLength;
}

unsigned int _stdcall PackProcessIndex(TEntry* Entry,
	unsigned int Indexs, void** Output) {
	int i;
	char Name[32];
	dat_entry_t* indexs;
	indexs = (dat_entry_t *)GetMemory(Indexs*sizeof(dat_entry_t));
	*Output = indexs;
	for (i = 0; i <Indexs; i++) {
FillMemory(Name,32,0x0);
		WideCharToMultiByte(CP_ACP, 0, Entry[i].AName, -1, Name, 32,NULL,NULL);
		memcpy(indexs[i].name, Name, 32);
		indexs[i].offset = Entry[i].AOffset + Indexs*sizeof(dat_entry_t)+sizeof
			(dat_header_t);
		indexs[i].comprlen = Entry[i].AStoreLength;
		indexs[i].uncomprlen = Entry[i].ARLength;
		indexs[i].mode = 0x20000000;
	}
	return Indexs*sizeof(dat_entry_t);
}

unsigned int _stdcall MakePackage(TEntry* Entry,
	unsigned int Indexs, void* FileData, unsigned int FileDataSize,
	void* IndexData, unsigned int IndexDataSize, unsigned int Package) {
	dat_header_t head;
	unsigned long size;
	head.index_entries = Indexs;
	head.dummy_index_entries = head.index_entries;
	memcpy(head.magic, "PACKDAT.", 8);
	WriteFile((HANDLE)Package, &head, sizeof(dat_header_t), &size, 0);
	WriteFile((HANDLE)Package, IndexData, IndexDataSize, &size, 0);
	WriteFile((HANDLE)Package, FileData, FileDataSize, &size, 0);
	return 1;
}

BOOL APIENTRY DllMain(HINSTANCE hInst /* Library instance handle. */ ,
	DWORD reason /* Reason this function is being called. */ ,
	LPVOID reserved /* Not used. */) {
	switch (reason) {
	case DLL_PROCESS_ATTACH:
		break;

	case DLL_PROCESS_DETACH:
		break;

	case DLL_THREAD_ATTACH:
		break;

	case DLL_THREAD_DETACH:
		break;
	}

	/* Returns TRUE on success, FALSE on failure */
	return TRUE;
}
