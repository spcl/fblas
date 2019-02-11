/**
    FBLAS: BLAS implementation for Intel FPGA
    Copyright (c) 2019 ETH-Zurich. All rights reserved.
    See LICENSE for license information.

    Reads a matrix of type TYPE_T from memory and  push it
    into CHANNEL_MATRIX_A. The matrix is read considering the presence of a
    two level tiling (memory/computational) like the one present in SYRK implementation.

    In this kernel we read the left-most matrix of the computation
    Each InnerBlock is sent only once (will be buffered by the receiver)
    Matrix A is sent by column (since it is non-transposed)
    Each tile-row ti of A is sent a  different number of time, depending on the
    type of SYRK computation:
    - if C is lower triangular, it will be sent ti times
    - if C is upper triangular, it will be sent NumTile-ti


    8 reads are performed simultaneously (this value has been choosen as a trade off between
    generated hardware and speed. In the future can be considered as a parameter).
    If needed, data is padded to tile sizes using zero elements.

*/

__kernel void READ_MATRIX_A(__global volatile TYPE_T * restrict A, const unsigned int N, const unsigned int K, const unsigned int lda, unsigned int lower)
{

    const int OuterBlocksN = 1 + (int)((N-1) / MTILE);
    const int InnerBlocksN = MTILE / CTILE_ROWS;
    const int BlocksK=(int)(K/MTILE);

    //the parameter lower indicates if C is lower (lower=1) or upper (lower=0) triangular
    if(lower!=0 && lower !=1) return;
    int tj_start,tj_end;
    TYPE_T localA[MTILE];
    for(int ti=0; ti< OuterBlocksN;ti++)
    {

        if(lower==1){
            tj_start=0;
            tj_end=ti;
        }
        else{
            tj_start=ti;
            tj_end=OuterBlocksN-1;
        }

        //resend this tile a number of times equal to the number of column tiles of the matrix B
        for(int tj=tj_start;tj<=tj_end;tj++)
        {
            for(int k=0;k<K;k++)
            {
                //load A
                #pragma unroll 8
                for(int i=0;i<MTILE;i++)
                {
                    if(ti*MTILE+i < N)
                        localA[i]=A[(ti*MTILE+i)*lda+k];
                    else
                        localA[i]=0;
                }

                //now we have to iterates over the inner tiles of size CTILE_ROWS x MTILE
                //each of them will be sent only once (and will be reused InnerBlocksM times)
                for(int tti=0; tti<InnerBlocksN;tti++)
                {
                    #pragma unroll
                    for(int i=0;i<CTILE_ROWS;i++)
                    {
                        write_channel_intel(CHANNEL_MATRIX_A,localA[tti*CTILE_ROWS+i]);
                    }
                }
            }
        }
    }
}
