obj-m := fb_ili9341_eb904.o
#-objs := fb_ili9341_eb904.o

all: 
	$(MAKE) -C $(STAGING_DIR) ARCH=$(ARCH) SUBDIRS=$(PWD) modules

clean:
	rm -f $(COMM_OBJS) $(MII_OBJS) $(PCI_OBJS) $(PLATFORM_OBJS) $(USB_OBJS) $(MESH_OBJS) $(WIDI_OBJS) Module.symvers *~ .*.cmd *.map *.o *.ko *.mod.c comm/.*.cmd pci/.*.cmd mii/.*.cmd widi/.*.cmd usb/.*.cmd platform/.*.cmd *.order
	for d in $(subdir-m); \
    do                       \
      $(MAKE) --directory=$$d $@; \
    done


