//
//	memory.c
//
//	Routines for dealing with memory management.

//static char rcsid[] = "$Id: memory.c,v 1.1 2000/09/20 01:50:19 elm Exp elm $";

#include "ostraps.h"
#include "dlxos.h"
#include "process.h"
#include "memory.h"
#include "queue.h"

// num_pages = size_of_memory / size_of_one_page
// 2048KB/4KB / 32 = 16 int32s
static uint32 freemap[MEM_MAX_SIZE/MEM_PAGESIZE/32];
static uint32 pagestart = 0;
static int nfreepages;
static int freemapmax = MEM_MAX_SIZE/MEM_PAGESIZE;

//----------------------------------------------------------------------
//
//	This silliness is required because the compiler believes that
//	it can invert a number by subtracting it from zero and subtracting
//	an additional 1.  This works unless you try to negate 0x80000000,
//	which causes an overflow when subtracted from 0.  Simply
//	trying to do an XOR with 0xffffffff results in the same code
//	being emitted.
//
//----------------------------------------------------------------------
static int negativeone = 0xFFFFFFFF;
static inline uint32 invert (uint32 n) {
  return (n ^ negativeone);
}

//----------------------------------------------------------------------
//
//	MemoryGetSize
//
//	Return the total size of memory in the simulator.  This is
//	available by reading a special location.
//
//----------------------------------------------------------------------
int MemoryGetSize() {
  return (*((int *)DLX_MEMSIZE_ADDRESS));
}


//----------------------------------------------------------------------
//
//	MemoryModuleInit
//
//	Initialize the memory module of the operating system.
//      Basically just need to setup the freemap for pages, and mark
//      the ones in use by the operating system as "VALID", and mark
//      all the rest as not in use.
//
//----------------------------------------------------------------------
void MemoryModuleInit() {
  int i;
  
  nfreepages = freemapmax;
  for (i = 0;i < lastosaddress >> MEM_L1FIELD_FIRST_BITNUM;++i){
    freemap[i >> 5] = freemap[i >> 5] | (1 << (i << 27 >> 27));
    nfreepages--;
  }
}


//----------------------------------------------------------------------
//
// MemoryTranslateUserToSystem
//
//	Translate a user address (in the process referenced by pcb)
//	into an OS (physical) address.  Return the physical address.
//
//----------------------------------------------------------------------
uint32 MemoryTranslateUserToSystem (PCB *pcb, uint32 addr) {
  int virtualPageNum = addr >> MEM_L1FIELD_FIRST_BITNUM;
  int pageTableEntry = pcb->pagetable[virtualPageNum];
  uint32 offset;
  uint32 phyPageBase;
  uint32 phyAddr;

  uint32 stackAddr;

  stackAddr = pcb->currentSavedFrame[PROCESS_STACK_USER_STACKPOINTER];
  //  printf("Pid %d, Faddr %x, Saddr %x\n", GetCurrentPid(), addr, stackAddr);

  dbprintf('m', "MemoryTranslateUserToSystem (%d): Starting!\n", GetCurrentPid());
  if (!(pageTableEntry & MEM_PTE_VALID)){
    // Save fault address to PROCESS_STACK_FAULT register
    pcb->currentSavedFrame[PROCESS_STACK_FAULT] = addr;
   
    if (MemoryPageFaultHandler(pcb) == MEM_FAIL){
      //Seg fault, the process is killed
      return 0;
    }
    pcb->npages++;
  }
    
  offset = addr & MEM_ADDRESS_OFFSET_MASK;
  phyPageBase = (pageTableEntry >> MEM_L1FIELD_FIRST_BITNUM) << MEM_L1FIELD_FIRST_BITNUM;
  phyAddr = phyPageBase | offset;
  dbprintf('m', "MemoryTranslateUserToSystem (%d): Done!\n", GetCurrentPid());
  return phyAddr;
}


//----------------------------------------------------------------------
//
//	MemoryMoveBetweenSpaces
//
//	Copy data between user and system spaces.  This is done page by
//	page by:
//	* Translating the user address into system space.
//	* Copying all of the data in that page
//	* Repeating until all of the data is copied.
//	A positive direction means the copy goes from system to user
//	space; negative direction means the copy goes from user to system
//	space.
//
//	This routine returns the number of bytes copied.  Note that this
//	may be less than the number requested if there were unmapped pages
//	in the user range.  If this happens, the copy stops at the
//	first unmapped address.
//
//----------------------------------------------------------------------
int MemoryMoveBetweenSpaces (PCB *pcb, unsigned char *system, unsigned char *user, int n, int dir) {
  unsigned char *curUser;         // Holds current physical address representing user-space virtual address
  int		bytesCopied = 0;  // Running counter
  int		bytesToCopy;      // Used to compute number of bytes left in page to be copied

  while (n > 0) {
    // Translate current user page to system address.  If this fails, return
    // the number of bytes copied so far.
    curUser = (unsigned char *)MemoryTranslateUserToSystem (pcb, (uint32)user);

    // If we could not translate address, exit now
    if (curUser == (unsigned char *)0) break;

    // Calculate the number of bytes to copy this time.  If we have more bytes
    // to copy than there are left in the current page, we'll have to just copy to the
    // end of the page and then go through the loop again with the next page.
    // In other words, "bytesToCopy" is the minimum of the bytes left on this page 
    // and the total number of bytes left to copy ("n").

    // First, compute number of bytes left in this page.  This is just
    // the total size of a page minus the current offset part of the physical
    // address.  MEM_PAGESIZE should be the size (in bytes) of 1 page of memory.
    // MEM_ADDRESS_OFFSET_MASK should be the bit mask required to get just the
    // "offset" portion of an address.
    bytesToCopy = MEM_PAGESIZE - ((uint32)curUser & MEM_ADDRESS_OFFSET_MASK);
    
    // Now find minimum of bytes in this page vs. total bytes left to copy
    if (bytesToCopy > n) {
      bytesToCopy = n;
    }

    // Perform the copy.
    if (dir >= 0) {
      bcopy (system, curUser, bytesToCopy);
    } else {
      bcopy (curUser, system, bytesToCopy);
    }

    // Keep track of bytes copied and adjust addresses appropriately.
    n -= bytesToCopy;           // Total number of bytes left to copy
    bytesCopied += bytesToCopy; // Total number of bytes copied thus far
    system += bytesToCopy;      // Current address in system space to copy next bytes from/into
    user += bytesToCopy;        // Current virtual address in user space to copy next bytes from/into
  }
  return (bytesCopied);
}

//----------------------------------------------------------------------
//
//	These two routines copy data between user and system spaces.
//	They call a common routine to do the copying; the only difference
//	between the calls is the actual call to do the copying.  Everything
//	else is identical.
//
//----------------------------------------------------------------------
int MemoryCopySystemToUser (PCB *pcb, unsigned char *from,unsigned char *to, int n) {
  return (MemoryMoveBetweenSpaces (pcb, from, to, n, 1));
}

int MemoryCopyUserToSystem (PCB *pcb, unsigned char *from,unsigned char *to, int n) {
  return (MemoryMoveBetweenSpaces (pcb, to, from, n, -1));
}

//---------------------------------------------------------------------
// MemoryPageFaultHandler is called in traps.c whenever a page fault 
// (better known as a "seg fault" occurs.  If the address that was
// being accessed is on the stack, we need to allocate a new page 
// for the stack.  If it is not on the stack, then this is a legitimate
// seg fault and we should kill the process.  Returns MEM_SUCCESS
// on success, and kills the current process on failure.  Note that
// fault_address is the beginning of the page of the virtual address that 
// caused the page fault, i.e. it is the vaddr with the offset zero-ed
// out.
//
// Note: The existing code is incomplete and only for reference. 
// Feel free to edit.
//---------------------------------------------------------------------
int MemoryPageFaultHandler(PCB *pcb) {
  uint32 phyPage;
  uint32 faultAddr;
  uint32 stackAddr;

  faultAddr = pcb->currentSavedFrame[PROCESS_STACK_FAULT] >> MEM_L1FIELD_FIRST_BITNUM << MEM_L1FIELD_FIRST_BITNUM;
  stackAddr = pcb->currentSavedFrame[PROCESS_STACK_USER_STACKPOINTER] >> MEM_L1FIELD_FIRST_BITNUM << MEM_L1FIELD_FIRST_BITNUM;
  // Segmentation fault
  if (faultAddr < stackAddr){
    printf("Pid %d, Faddr %x, Saddr %x\n", GetCurrentPid(), faultAddr, stackAddr);
    dbprintf('m', "MemoryPageFaultHandler (%d): Segmentation fault!\n", GetPidFromAddress(pcb));
    printf("MemoryPageFaultHandler (%d): Segmentation fault!\n", GetPidFromAddress(pcb));
    ProcessKill();
    return MEM_FAIL;
  }
  
  phyPage = MemoryAllocPage();
  pcb->pagetable[faultAddr >> MEM_L1FIELD_FIRST_BITNUM] = MemorySetupPte(phyPage);
  dbprintf('m', "MemoryPageFaultHandler (%d): Alloc new page for stack!\n", GetPidFromAddress(pcb));
  
  return MEM_SUCCESS;
}


//---------------------------------------------------------------------
// You may need to implement the following functions and access them from process.c
// Feel free to edit/remove them
//---------------------------------------------------------------------

int MemoryAllocPage(void) {
  int firstValidFreemap;
  int i;
  dbprintf('m', "MemoryAllocPage (%d): Starting!\n", GetCurrentPid());

  if(nfreepages != 0){
    for(i = 0;i < freemapmax >> 5;++i){
      if (freemap[i] != negativeone)
	break;
    }
    firstValidFreemap = i;
    if (firstValidFreemap != freemapmax >> 5){
      for(i = 0;i < 1 << 5;++i){
	if((freemap[firstValidFreemap] & (1 << i)) == 0){
	  freemap[firstValidFreemap] = freemap[firstValidFreemap] | (1 << i);
	  nfreepages--;
	  dbprintf('m', "MemoryAllocPage (%d): Success!\n", GetCurrentPid());
	  
	  //printf("freepagenum: %d\n", i);
	  return (i + (firstValidFreemap << 5)) << MEM_L1FIELD_FIRST_BITNUM;
	}
      }
    }
  }
  dbprintf('m', "MemoryAllocPage (%d): Failed!", GetCurrentPid());
  return -1;
}


uint32 MemorySetupPte (uint32 page) {
  return page | MEM_PTE_VALID;
}


void MemoryFreePage(uint32 page) {
  int phyPageNum = page >> MEM_L1FIELD_FIRST_BITNUM;
  freemap[phyPageNum >> 5] = freemap[phyPageNum >> 5] & invert(1 << (phyPageNum << 27 >> 27));
  nfreepages++;
  dbprintf('m', "MemoryFreePage (%d): Success!", GetCurrentPid());
}

int malloc(PCB *pcb, int ihandle){
  return 0;
}

int mfree(PCB *pcb, int ihandle){
  return 0;
}