#!/usr/bin/python
# version:  2021/09/10
# Credit : Modify from PreQual: https://github.com/MASILab/PreQual (by Leon Cai and Qi Yang, MASI Lab, Vanderbilt University)
# iDIO QC vars function


# Set Up

import os

# Define class to hold shared variables

class SharedVars():

    def __init__(self):

        self.VERSION = '1.0'
        self.NUM_THREADS = 1 # Note: This value must be >= 1. Use 1 for spider on ACCRE. In MRTrix3, nthreads = 0 disables multithreading, so we use NUM_THREADS-1 for MRTrix3 commands

        # Define visualization variables
        self.PAGESIZE = (10.5, 8)
        self.TITLE_FONTSIZE = 16
        self.LABEL_FONTSIZE = 10
        self.PDF_DPI = 300
        self.VIS_PERCENTILE_MAX = 99.9

# Define instance of SharedVars class that will be accessible to (and editable by) other modules

SHARED_VARS = SharedVars()