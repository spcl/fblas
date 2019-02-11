/**
    FBLAS: BLAS implementation for Intel FPGA
    Copyright (c) 2019 ETH-Zurich. All rights reserved.
    See LICENSE for license information.

    This helper is intended to be used with TRSV (v4)

    Reads a triangular lower matrix of type TYPE_T from memory and  push it
    into CHANNEL_MATRIX_A, starting from the bottom row-tile.
    The matrix is row streamed, with tiles produced by column.
    For each column-tile, tiles are produced in the reverse order,
    i.e. bottom up.
    Given a particular row (inside a tile), elements are produced in the natural order, i.e.
    from left to right.

    The matrix is sent in packed format, i.e. for each row only the meaningful
    elements are sent, padded to W.

    The name of the kernel can be redefined by means of preprocessor macro READ_MATRIX_A.
    Tile sizes must be defined by Macros.

    W reads are performed simultaneously.
    If needed, data is padded to tile sizes using zero elements.

    To be used with trsv_v4
*/
__kernel void READ_MATRIX_A(__global volatile TYPE_T *restrict data, int N,unsigned int lda)
{
    const int BlocksN=1+(int)((N-1)/TILE_N);

    TYPE_T to_send[W];
    for(int tj=BlocksN-1;tj>=0;tj--)
    {
        for(int ti=BlocksN-1;ti>=tj;ti--)
        {

            for(int i = TILE_N-1; i >=0; i--)
            {
                const int outer_loop_limit=(ti>tj)?((int)(TILE_N/W)):ceilf(((float)(i+1))/W);
                int i_idx=ti*TILE_N+i;
                for(int j=0;j<outer_loop_limit;j++)
                {
                    //prepare data
                    #pragma unroll
                    for(int jj=0;jj<W;jj++)
                    {
                        int j_idx=tj*TILE_N+j*W+jj;
                        if(j_idx<=i_idx && i_idx < N && j_idx < N)
                            to_send[jj]=data[i_idx*lda+j_idx];
                        else
                            to_send[jj]=0;
                    }

                    #pragma unroll
                    for(int jj=0;jj<W;jj++)
                        write_channel_intel(CHANNEL_MATRIX_A,to_send[jj]);
                }
            }
        }
    }
}
