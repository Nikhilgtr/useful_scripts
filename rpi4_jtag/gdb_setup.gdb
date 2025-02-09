set pagination off
set confirm off

# Enable verbose debugging (optional)
#set debug remote 1

# Connect to the target
target extended-remote :3333

# Load symbols (optional, update path if needed)
# symbol-file vmlinux

# Display registers after connection
#info registers

# Set a breakpoint at main (or another function)
# b main

# Continue execution automatically (optional)
# continue

