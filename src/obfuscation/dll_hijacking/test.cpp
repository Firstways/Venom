#include <windows.h>
#include <iostream>

typedef void (__stdcall *PayloadFunc)();

int main()
{
	HMODULE hDll = LoadLibraryA("version.dll");
	if (!hDll)
	{
		std::cout << "Erreur LoadLibrary: " << GetLastError() << std::endl;
		return 1;
	}

	PayloadFunc payload = (PayloadFunc)GetProcAddress(hDll, "Payload@16");

	if (!payload)
	{
		std::cout << "Erreur GetProcAddress: " << GetLastError() << std::endl;
		return 1;
	}

	payload();

	return 0;
}