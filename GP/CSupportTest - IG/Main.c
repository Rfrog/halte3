
#include <windows.h>

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
} TEntry;

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

#pragma argsused

__declspec(dllexport) wchar_t* _stdcall GetPluginName() {
	return L"[M]Innocent Grey";
}

__declspec(dllexport) void* _stdcall GetMemory(unsigned int Size) {
	return malloc(Size);
}

__declspec(dllexport) unsigned int _stdcall FreeMemory(void* Memory) {
	free(Memory);
	return 1;
}

__declspec(dllexport) unsigned int _stdcall GenerateEntries(unsigned int Input,
    TEntry** Output) {
	dat_header_t head;
	dat_entry_t* indexs;
	unsigned long size;
	unsigned int i;
	wchar_t Name[32];
	ReadFile((HANDLE)Input, &head, sizeof(dat_header_t), &size, 0);
	indexs = GetMemory(head.index_entries*sizeof(dat_entry_t));
	size = head.index_entries * sizeof(dat_entry_t);
	ReadFile((HANDLE)Input, indexs, head.index_entries * sizeof(dat_entry_t),
		&size, 0);
	*Output = GetMemory(head.index_entries * sizeof(TEntry));
	for (i = 0; i < head.index_entries; i++) {
		MultiByteToWideChar(CP_ACP,0,indexs[i].name,-1,Name,32);
		memcpy((*Output)[i].AName, Name, 32);
		(*Output)[i].AOffset = indexs[i].offset;
		(*Output)[i].AStoreLength = indexs[i].comprlen;
		(*Output)[i].ARLength = indexs[i].uncomprlen;
		(*Output)[i].AKey = indexs[i].mode;
		(*Output)[i].AOrigin = FILE_BEGIN;
	}
	FreeMemory(indexs);
	return head.index_entries * sizeof(TEntry);
}

__declspec(dllexport) unsigned int _stdcall ReadData(unsigned int Input,
	TEntry* Entry, void** Output) {
	unsigned long size;
	*Output = GetMemory(Entry->AStoreLength);
	SetFilePointer((HANDLE)Input, Entry->AOffset, 0, Entry->AOrigin);
	ReadFile((HANDLE)Input, *Output, Entry->AStoreLength, &size, 0);
	return size;
}

int WINAPI DllEntryPoint(HINSTANCE hinst, unsigned long reason,
	void* lpReserved) {
	return 1;
}

// ---------------------------------------------------------------------------
