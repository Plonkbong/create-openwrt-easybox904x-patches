/*
 * FB driver for the ILI9341 LCD display controller in the Easybox 904
 *
 * Copyright (C) 2013 Christian Vogelgsang
 * Based on adafruit22fb.c by Noralf Tronnes
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#include <linux/module.h>
#include <linux/delay.h>
#include <video/mipi_display.h>
#include <lantiq_soc.h>

#include "fbtft.h"

extern spinlock_t ebu_lock;


#define LCD_DAT_MMAP_OFF	0		// Offset to data register in memmapped region
#define LCD_CMD_MMAP_OFF	2		// Offset to command register in memmapped region

#define	LCD_CMD_LOWBYTE		0x0		// Value to put into low byte for commands
#define	LCD_DAT_LOWBYTE		0x0		// Value to put into low byte for data


#define DRVNAME		"fb_ili9341_eb904"
#define WIDTH		240
#define HEIGHT		320
#define TXBUFLEN	(4 * PAGE_SIZE)
#define DEFAULT_GAMMA	"1F 1A 18 0A 0F 06 45 87 32 0A 07 02 07 05 00\n" \
			"00 25 27 05 10 09 3A 78 4D 05 18 0D 38 3A 1F"
#define UBOOT_GAMMA	"0F 1B 17 0C 0D 08 40 A9 28 06 0D 03 10 03 00\n" \
			"00 24 28 03 12 07 3F 56 57 09 12 0C 2F 3C 0F"


// Replacements for write_reg macro where name indicates if it is guarded
// without/with EBU spinlocking code
static void fbtft_write_reg8_bus8_ebu(struct fbtft_par *par, int len, ...);
#define write_reg_nolock(par, ...)						\
	(fbtft_write_reg8_bus8_ebu(par, NUMARGS(__VA_ARGS__), __VA_ARGS__))

static void fbtft_write_reg8_bus8_ebu_smp(struct fbtft_par *par, int len, ...);
#define write_reg_lock(par, ...)						\
	(fbtft_write_reg8_bus8_ebu_smp(par, NUMARGS(__VA_ARGS__), __VA_ARGS__))


// Lowlevel access to registers of fb controller
static void lcd_WriteCommand(struct fbtft_par *par, u8 iReg)
{
	void __iomem  *addr = par->pdata->extra + LCD_CMD_MMAP_OFF;

	// printk("%s: Write command 0x%04x\n",__FUNCTION__, iReg);

	ndelay(20);
	__raw_writew(0x0 | LCD_CMD_LOWBYTE, addr);

	ndelay(20);
	__raw_writew((iReg << 8) | LCD_CMD_LOWBYTE, addr);
}

static void lcd_WriteData(struct fbtft_par *par, const u8 *buf, size_t len)
{
	void __iomem  *addr = par->pdata->extra + LCD_DAT_MMAP_OFF;

	while (len--) {
		ndelay(20);
		__raw_writew((*buf++ << 8) | LCD_DAT_LOWBYTE, addr);
	}
}

static u16 lcd_ReadData(struct fbtft_par *par)
{
	volatile void __iomem  *addr = par->pdata->extra + LCD_DAT_MMAP_OFF;
	u16  high, low;

	ndelay(20);
	high = __raw_readw(addr);

	ndelay(20);
	low = __raw_readw(addr);

	return  (high & 0xff00) | (low >> 8);
}

static unsigned short ili9341_GetControllerID_smp(struct fbtft_par *par)
{
	unsigned long	lockflags;
	unsigned short	iParameter1;
	unsigned short	iParameter2;

	spin_lock_irqsave(&ebu_lock, lockflags);

	lcd_WriteCommand(par, 0xD3);

	iParameter1 = lcd_ReadData(par);
	iParameter2 = lcd_ReadData(par);

	spin_unlock_irqrestore(&ebu_lock, lockflags);

	return iParameter2;
}


// EBU address select register bits
#define ADDSEL_BASE(x)		(x << 12)	// FFFFF000	5 to 20 bits (depending on MASK), starting from left
#define ADDSEL_MASK(x)		(x << 4)	// 000000F0	4 bits
#define ADDSEL_MIRRORE		(1 << 2)	// 00000002
#define ADDSEL_REGEN		(1 << 0)	// 00000001

// EBU configuration register bits eed to tell the EBU that we have the display attached and set it up properly
#define BUSCON_WRDIS		(1 << 31)	// 80000000
#define BUSCON_ADSWP		(1 << 30)	// 40000000
#define BUSCON_PG_EN		(1 << 29)	// 20000000
#define BUSCON_AGEN(x)		(x << 24)	// 07000000	3 bits	AGEN_DEMUX/RES/MUX/-/-/-/-/-
#define BUSCON_SETUP_EN		(1 << 22)	// 00400000
#define BUSCON_WAIT(x)		(x << 20)	// 00300000	2 bits	WAIT_DISABLE/ASYNC/SYNC/-
#define	BUSCON_WAITINV_HI	(1 << 19)	// 00080000
#define BUSCON_VN_EN		(1 << 18)	// 00040000
#define BUSCON_XDM(x)		(x << 16)	// 00030000	2 bits	XDM8/16/-/-
#define BUSCON_ALEC(x)		(x << 14)	// 6000C000	2 bits	ALEC0/1/2/3
#define BUSCON_BCGEN(x)		(x << 12)	// 00003000	2 bits	BCGEN_CS/INTEL/MOTOROLA/RES
#define BUSCON_WAITWRC(x)	(x << 8)	// 00000700	3 bits	WAITWRC0/1/2/3/4/5/6/7
#define BUSCON_WAITRDC(x)	(x << 6)	// 000000C0	2 bits	WAITRDC0/1/2/3
#define BUSCON_HOLDC(x)		(x << 4)	// 00000030	2 bits	HOLDC0/1/2/3
#define BUSCON_RECOVC(x)	(x << 2)	// 0000000C	2 bits	RECOVC0/1/2/3
#define BUSCON_CMULT(x)		(x << 0)	// 00000003	2 bits	CMULT1/4/8/16

static int ili9341_Probe_smp(struct fbtft_par *par)
{
	struct resource	*res;
	unsigned short id;

	// From DTS, determine addr space into which to map the fb controller registers
	res = platform_get_resource(par->pdev, IORESOURCE_MEM, 0);
	par->pdata->extra = devm_ioremap_resource(&par->pdev->dev, res);
	printk("%s: mapped to %p\n", __FUNCTION__, par->pdata->extra);

	if (IS_ERR(par->pdata->extra))
		return 0;

	// Set EBU addr select reg #2 to map fb controller regs into address space within KSEG1 area
        ltq_ebu_w32(CPHYSADDR(par->pdata->extra)	// Addr prefix (without KSEG1 prefix) for fb controller registers
		    | ADDSEL_MASK(15)			// Use 5+15 most significant bits of CPHYSADDR()
		    | ADDSEL_REGEN,
		    LTQ_EBU_ADDRSEL2);

	// Set EBU bus configuration register #2; 0x1d3dd (resp. 0x1d7ff) used by original Arcadyan Linux (resp. U-Boot)
        ltq_ebu_w32(BUSCON_XDM(1)			// XDM16
		    | BUSCON_ALEC(3)			// ALEC3
		    | BUSCON_BCGEN(1)			// BCGEN_INTEL
		    | BUSCON_WAITWRC(3)			// WAITWRC3
		    | BUSCON_WAITRDC(3)			// WAITRDC3
		    | BUSCON_HOLDC(1)			// HOLDC1	BUSCON_HOLDC(3) used in U-Boot
		    | BUSCON_RECOVC(3)			// RECOVC3
		    | BUSCON_CMULT(1),			// CMULT4	BUSCON_CMULT(3)==CMULT16 used in U-Boot
		    LTQ_EBU_BUSCON2);

	// Query id to determine if fb controller is present
	id = ili9341_GetControllerID_smp(par);
	printk("%s: Probed ID4: %x\n", __FUNCTION__, id);

	return id == 0x9341;
}


#if 0	/// Code from U-Boot
static int init_display_uboot(struct fbtft_par *par)
	{
	// VCI=2.8V
		ili9341_Probe();
	//************* Start Initial Sequence **********//
//		lcd_WriteCommand(0xCB);
//		lcd_WriteData(0x392C);
//		lcd_WriteData(0x0034);
//		lcd_WriteData(0x0200);
		write_reg(par, 0xCB, 0x39, 0x2C, 0x00, 0x34, 0x02, 0x00);

//		lcd_WriteCommand(0xCF);
//		lcd_WriteData(0x00C1);
//		lcd_WriteData(0X3000);
		write_reg(par, 0xCF, 0x00, 0xC1, 0x30, 0x00);

//		lcd_WriteCommand(0xE8);
//		lcd_WriteData(0x8510);
//		lcd_WriteData(0x7900);
		write_reg(par, 0xE8, 0x85, 0x10, 0x79, 0x00);

//		lcd_WriteCommand(0xEA);
//		lcd_WriteData(0x0000);
		write_reg(par, 0xEA, 0x00, 0x00);

//		lcd_WriteCommand(0xED);
//		lcd_WriteData(0x6403);
//		lcd_WriteData(0X1281);
		write_reg(par, 0xED, 0x64, 0x03, 0x12, 0x81);

//		lcd_WriteCommand(0xF7);
//		lcd_WriteData(0x2000);
		write_reg(par, 0xF7, 0x20, 0x00);

//		lcd_WriteCommand(0xC0);	//Power control
//		lcd_WriteData(0x2100);	//VRH[5:0]
		write_reg(par, 0xC0, 0x21, 0x00);

//		lcd_WriteCommand(0xC1);	//Power control
//		lcd_WriteData(0x1200);	//SAP[2:0];BT[3:0]
		write_reg(par, 0xC1, 0x12, 0x00);

//		lcd_WriteCommand(0xC5);	//VCM control
//		lcd_WriteData(0x243F);
		write_reg(par, 0xC5, 0x24, 0x3F);

//		lcd_WriteCommand(0xC7);	//VCM control2
//		lcd_WriteData(0xC200);
		write_reg(par, 0xC7, 0xC2, 0x00);

//		lcd_WriteCommand(0xb1);	// Frame rate
//		lcd_WriteData(0x0016);
		write_reg(par, 0xB1, 0x00, 0x16);

//		lcd_WriteCommand(0x36);	// Memory Access Control
//		if ( lcd_GetOrientation() == LCD_ORIENTATION_LANDSCAPE)
//		  lcd_WriteData(0x4800);//08 48
//		else
//		  lcd_WriteData(0x3800);

//		lcd_WriteCommand(0x3A);
//		lcd_WriteData(0x5500);
		write_reg(par, 0x3A, 0x55, 0x00);

//		lcd_WriteCommand(0xF2);	// 3Gamma Function Disable
//		lcd_WriteData(0x0000);
		write_reg(par, 0xF2, 0x00, 0x00);

//		lcd_WriteCommand(0x26);	//Gamma curve selected
//		lcd_WriteData(0x0100);
		write_reg(par, 0x26, 0x01, 0x00);

//		lcd_WriteCommand(0xE0);	//Set Gamma
//		lcd_WriteData(0x0F1B);
//		lcd_WriteData(0x170C);
//		lcd_WriteData(0x0D08);
//		lcd_WriteData(0x40A9);
//		lcd_WriteData(0x2806);
//		lcd_WriteData(0x0D03);
//		lcd_WriteData(0x1003);
//		lcd_WriteData(0x0000);
		write_reg(par, 0xE0,
			0x0F, 0x1B,
			0x17, 0x0C,
			0x0D, 0x08,
			0x40, 0xA9,
			0x28, 0x06,
			0x0D, 0x03,
			0x10, 0x03,
			0x00, 0x00
			);

//		lcd_WriteCommand(0XE1);	//Set Gamma
//		lcd_WriteData(0x0024);
//		lcd_WriteData(0x2803);
//		lcd_WriteData(0x1207);
//		lcd_WriteData(0x3F56);
//		lcd_WriteData(0x5709);
//		lcd_WriteData(0x120C);
//		lcd_WriteData(0x2F3C);
//		lcd_WriteData(0x0F00);
		write_reg(par, 0xE1,
			0x00, 0x24,
			0x28, 0x03,
			0x12, 0x07,
			0x3F, 0x56,
			0x57, 0x09,
			0x12, 0x0C,
			0x2F, 0x3C,
			0x0F, 0x00
			);

//		lcd_WriteCommand(0x11);	//Exit Sleep
		write_reg(par, 0x11);
		mdelay(120);
//		lcd_WriteCommand(0x29);	//Display on
		write_reg(par, 0x29);

		return 0;
	}
#endif	// #if 0	// Code from U-Boot?


static int init_display_smp(struct fbtft_par *par)
{
	unsigned long lockflags;

	par->fbtftops.reset(par);

	if (!ili9341_Probe_smp(par))
		return -ENODEV;

	spin_lock_irqsave(&ebu_lock, lockflags);

	/* startup sequence for MI0283QT-9A */
	write_reg_nolock(par, MIPI_DCS_SOFT_RESET);
	mdelay(5);
	write_reg_nolock(par, MIPI_DCS_SET_DISPLAY_OFF);
	/* --------------------------------------------------------- */
	write_reg_nolock(par, 0xCF, 0x00, 0x83, 0x30);
	write_reg_nolock(par, 0xED, 0x64, 0x03, 0x12, 0x81);
	write_reg_nolock(par, 0xE8, 0x85, 0x01, 0x79);
	write_reg_nolock(par, 0xCB, 0x39, 0X2C, 0x00, 0x34, 0x02);
	write_reg_nolock(par, 0xF7, 0x20);
	write_reg_nolock(par, 0xEA, 0x00, 0x00);
	/* ------------power control-------------------------------- */
//	write_reg_nolock(par, 0xC0, 0x26);
//	write_reg_nolock(par, 0xC1, 0x11);
	write_reg_nolock(par, 0xC0, 0x21);			// VRH[5:0]
	write_reg_nolock(par, 0xC1, 0x12);			// SAP[2:0];BT[3:0]

	/* ------------VCOM --------- */
//	write_reg_nolock(par, 0xC5, 0x35, 0x3E);
//	write_reg_nolock(par, 0xC7, 0xBE);
	write_reg_nolock(par, 0xC5, 0x24, 0x3F);		// VCM control
	write_reg_nolock(par, 0xC7, 0xC2);			// VCM control2
	/* ------------memory access control------------------------ */
	write_reg_nolock(par, MIPI_DCS_SET_PIXEL_FORMAT, 0x55);	// 16bit pixel
	/* ------------frame rate----------------------------------- */
	// write_reg_nolock(par, 0xB1, 0x00, 0x1B);
	write_reg_nolock(par, 0xB1, 0x00, 0x16);		// uboot
	/* ------------Gamma---------------------------------------- */
	/* write_reg_nolock(par, 0xF2, 0x08); */ /* Gamma Function Disable */
	write_reg_nolock(par, MIPI_DCS_SET_GAMMA_CURVE, 0x01);
	/* ------------display-------------------------------------- */
	write_reg_nolock(par, 0xB7, 0x07);			// entry mode set
	/* ------------additional values---------------------------- */
	write_reg_nolock(par, 0x13);				// normal display mode on
	write_reg_nolock(par, 0x38);				// idle mode off
	write_reg_nolock(par, 0x20);				// inversion mode off
	/* --------------------------------------------------------- */
	write_reg_nolock(par, 0xB6, 0x0A, 0x82, 0x27, 0x00);
	write_reg_nolock(par, MIPI_DCS_EXIT_SLEEP_MODE);
	mdelay(100);
	write_reg_nolock(par, MIPI_DCS_SET_DISPLAY_ON);
	mdelay(20);

	spin_unlock_irqrestore(&ebu_lock, lockflags);

	return 0;
}

static void set_addr_win_smp(struct fbtft_par *par, int xs, int ys, int xe, int ye)
{
	unsigned long lockflags;

	spin_lock_irqsave(&ebu_lock, lockflags);

	write_reg_nolock(par, MIPI_DCS_SET_COLUMN_ADDRESS,
		(xs >> 8) & 0xFF, xs & 0xFF, (xe >> 8) & 0xFF, xe & 0xFF);

	write_reg_nolock(par, MIPI_DCS_SET_PAGE_ADDRESS,
		(ys >> 8) & 0xFF, ys & 0xFF, (ye >> 8) & 0xFF, ye & 0xFF);

	write_reg_nolock(par, MIPI_DCS_WRITE_MEMORY_START);

	spin_unlock_irqrestore(&ebu_lock, lockflags);
}


#define MEM_Y   BIT(7) /* MY row address order */
#define MEM_X   BIT(6) /* MX column address order */
#define MEM_V   BIT(5) /* MV row / column exchange */
#define MEM_L   BIT(4) /* ML vertical refresh order */
#define MEM_H   BIT(2) /* MH horizontal refresh order */
#define MEM_BGR (3) /* RGB-BGR Order */

static int set_var_smp(struct fbtft_par *par)
{
	u8  mem;

	switch (par->info->var.rotate) {
	case 0:
		mem = MEM_X;
		break;
	case 270:
		mem = MEM_V | MEM_L;
		break;
	case 180:
		mem = MEM_Y;
		break;
	case 90:
		mem = MEM_Y | MEM_X | MEM_V;
		break;
	default:
		return 0;
	}

	write_reg_lock(par, MIPI_DCS_SET_ADDRESS_MODE, mem | (par->bgr << MEM_BGR));
	return 0;
}

/*
 * Gamma string format:
 *  Positive: Par1 Par2 [...] Par15
 *  Negative: Par1 Par2 [...] Par15
 */
#define CURVE(num, idx)  curves[num * par->gamma.num_values + idx]

static int set_gamma_smp(struct fbtft_par *par, u32 *curves)
{
	unsigned long lockflags;
	int i;

	spin_lock_irqsave(&ebu_lock, lockflags);

	for (i = 0; i < par->gamma.num_curves; i++)
		write_reg_nolock(par, 0xE0 + i,
			CURVE(i, 0), CURVE(i, 1), CURVE(i, 2),
			CURVE(i, 3), CURVE(i, 4), CURVE(i, 5),
			CURVE(i, 6), CURVE(i, 7), CURVE(i, 8),
			CURVE(i, 9), CURVE(i, 10), CURVE(i, 11),
			CURVE(i, 12), CURVE(i, 13), CURVE(i, 14));

	spin_unlock_irqrestore(&ebu_lock, lockflags);

	return 0;
}

static int fbtft_write_8_wr_ebu_smp(struct fbtft_par *par, void *buf, size_t len)
{
	unsigned long lockflags;

	spin_lock_irqsave(&ebu_lock, lockflags);
	lcd_WriteData(par, buf, len);
	spin_unlock_irqrestore(&ebu_lock, lockflags);

	return 0;
}

static int verify_gpios_ebu(struct fbtft_par *par)
{
	fbtft_par_dbg(DEBUG_VERIFY_GPIOS, par, "%s()\n", __func__);

//??	if (!par->pdev)
//??		return 0;

	return 0;
}

static void fbtft_write_reg8_bus8_ebu_v(struct fbtft_par *par, int len, va_list args)
{
	u8 *buf = par->buf;
	int i;

	for (i = 0; i < len; i++)
		buf[i] = (u8)va_arg(args, unsigned int);

	fbtft_par_dbg_hex(DEBUG_WRITE_REGISTER, par, par->info->device, u8, buf, len, "%s: ", __func__);

	lcd_WriteCommand(par, *buf);
	len--;

	if (len > 0)
		lcd_WriteData(par, buf+1, len);
}

static void fbtft_write_reg8_bus8_ebu(struct fbtft_par *par, int len, ...)
{
	va_list args;

	va_start(args, len);
	fbtft_write_reg8_bus8_ebu_v(par, len, args);
	va_end(args);
}

static void fbtft_write_reg8_bus8_ebu_smp(struct fbtft_par *par, int len, ...)
{
	unsigned long lockflags;
	va_list args;

	spin_lock_irqsave(&ebu_lock, lockflags);

	va_start(args, len);
	fbtft_write_reg8_bus8_ebu_v(par, len, args);
	va_end(args);

	spin_unlock_irqrestore(&ebu_lock, lockflags);
}

static struct fbtft_display display = {
	.regwidth = 8,
	.width = WIDTH,
	.height = HEIGHT,
	.txbuflen = TXBUFLEN,
	.gamma_num = 2,
	.gamma_len = 15,
	.gamma = UBOOT_GAMMA,
	.fbtftops = {
		.init_display = init_display_smp,
		.set_addr_win = set_addr_win_smp,
		.set_var = set_var_smp,
		.set_gamma = set_gamma_smp,
		.verify_gpios = verify_gpios_ebu,
		.write = fbtft_write_8_wr_ebu_smp,
		.write_register = fbtft_write_reg8_bus8_ebu_smp,
	},
};

FBTFT_REGISTER_DRIVER(DRVNAME, "ilitek,ili9341_eb904", &display);

MODULE_ALIAS("platform:" DRVNAME);
MODULE_ALIAS("platform:ili9341_eb904");

MODULE_DESCRIPTION("FB driver for the ILI9341 LCD display controller in the Easybox 904");
MODULE_AUTHOR("Christian Vogelgsang et al.");
MODULE_LICENSE("GPL");
