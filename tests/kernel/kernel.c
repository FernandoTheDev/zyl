void _start(void) {
    char* video = (char*)0xB8000;
    const char* msg = "Hello World!";
    
    for (int i = 0; i < 80 * 2; i += 2) {
        video[i] = ' ';
        video[i + 1] = 0x0F;
    }
    
    int i = 0;
    while (msg[i] != '\0') {
        video[i * 2] = msg[i];
        video[i * 2 + 1] = 0x0F;
        i++;
    }
    
    while (1) {}
}
