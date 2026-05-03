#include <windows.h>

extern "C" {
	__declspec(dllexport) int __stdcall Payload(HWND hwnd, HINSTANCE hinst, LPSTR lpszCmdLine, int nCmdShow)
	{
			Sleep(500);
			MessageBoxA(NULL, "DLL chargee !", "POC", 0);
			return 0;
	}
}
BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID)
{
	switch(reason){
		case DLL_PROCESS_ATTACH:
			DisableThreadLibraryCalls(hModule);
		case DLL_THREAD_ATTACH:
		case DLL_PROCESS_DETACH:
		case DLL_THREAD_DETACH:
			break;
	}

	return TRUE;
}