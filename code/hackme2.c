#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int check_password(char *password){
  struct password_state {
    char password_buffer[16];
    int correct;
  } state;

  state.correct = 0;

  strcpy(state.password_buffer, password);
  
  if (strcmp(state.password_buffer, "actualpw") == 0) {
    state.correct = 1;
  }
  
  return state.correct;
  
  
}


int main (int argc, char *argv[]) {
  if (argc < 2) {
		puts("Please enter your password as a command line parameter.");
  } else {
    if (check_password(argv[1])) {
      printf("Password correct.\n");
    } else {
      printf("Wrong password.\n");
    }
  }

  return 0;
  
}
