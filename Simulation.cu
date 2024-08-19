#include <iostream>
#include <stdio.h>
#include <cuda.h>
#include <chrono>
#include <set>
#define LLI long long int
// using namespace thrust;
using namespace std;

//*******************************************

// Write down the kernels here
__global__ void myMemSetInt(int *arr,int val,int size)
{
    if(threadIdx.x<size)
    arr[threadIdx.x]=val;
}




__global__ void dtanks(int *gxcoord, int * gycoord, int *gscore, int *ghealth, int *ghealthRead, int T, int N,
                         int *distance,  int *tanksLeft, int k){
    int cid=threadIdx.x;
    int sid=blockIdx.x;
    int did=(sid+k)%T;
    long long int x1=gxcoord[sid]; //source tanks
    long long int y1=gycoord[sid];
    long long int x2=gxcoord[did]; //destination tank
    long long int y2=gycoord[did];
    int dir=1;
    int dis=-2;
    

    if(did!=sid)
    {
        if(y2==y1)
        {
            if(x2<=x1)
            {
                dir=-1;
            }
        }
        else if(y1>y2)
        {
            dir=-1;
        }
    

        if(ghealthRead[sid]>0 && ghealthRead[cid]>0)
        {
            
                if(cid!=sid)
                {
                    long long int x=gxcoord[cid]; //current tank x coord
                    long long int y=gycoord[cid]; //current tank y coord
                    long long int lhs=((y-y1))*((x2-x1));
                    long long int rhs=((y2-y1))*((x-x1));

                    if(lhs==rhs) //condition to check whether the current tank lies in the direction of the fireline
                    {
                        if((dir>0 && (y1<y || (y1==y && x1<x))) || (dir<0 && (y1>y || (y==y1 && x1>x))))
                        {
                            dis=(abs(y-y1))+(abs(x-x1));
                            atomicMin(&distance[sid],dis);
                        }
                    }
                }
        }
    }
    __syncthreads();
    if(distance[sid]==dis)
    {
        atomicAdd(&gscore[sid],1);
        atomicSub(&ghealth[cid],1);
    }
}



__global__ void checktanks(int *ghealth, int *tanksleft)
{
    if(ghealth[threadIdx.x]<=0)
    {
        atomicSub(&tanksleft[0],1);
    }

    
}

// __global__ void SimulatingRounds(int *gpuk){
    
//     atomicAdd(&gpuk[0],1);
// }


//***********************************************


int main(int argc,char **argv)
{
    // printf("Hello Omlete");
    // Variable declarations
    int M,N,T,H,*xcoord,*ycoord,*score;
    

    FILE *inputfilepointer;
    
    //File Opening for read
    char *inputfilename = argv[1];
    inputfilepointer    = fopen( inputfilename , "r");

    if ( inputfilepointer == NULL )  {
        printf( "input.txt file failed to open." );
        return 0; 
    }

    fscanf( inputfilepointer, "%d", &M );
    fscanf( inputfilepointer, "%d", &N );
    fscanf( inputfilepointer, "%d", &T ); // T is number of Tanks
    fscanf( inputfilepointer, "%d", &H ); // H is the starting Health point of each Tank
	
    // Allocate memory on CPU
    xcoord=(int*)malloc(T * sizeof (int));  // X coordinate of each tank
    ycoord=(int*)malloc(T * sizeof (int));  // Y coordinate of each tank
    score=(int*)malloc(T * sizeof (int));  // Score of each tank (ensure that at the end you have copied back the score calculations on the GPU back to this allocation)

    // Get the Input of Tank coordinates
    for(int i=0;i<T;i++)
    {
      fscanf( inputfilepointer, "%d", &xcoord[i] );
      fscanf( inputfilepointer, "%d", &ycoord[i] );
    }
		

    auto start = chrono::high_resolution_clock::now();

    //*********************************
    // Your Code begins here (Do not change anything in main() above this comment)
    //********************************

    int *gxcoord, *gycoord, *gscore, *ghealth, *distance, *ghealthRead;
    
    // cudaDeviceSynchronize();

    cudaMalloc(&gxcoord,sizeof(int)*T);
    cudaMalloc(&gycoord,sizeof(int)*T);
    cudaMalloc(&gscore,sizeof(int)*T);
    cudaMalloc(&distance, sizeof(int)*T);
    // cudaMalloc(&CorrespondingIds, sizeof(int)*T);
    cudaMalloc(&ghealth, sizeof(int)*T);
    cudaMalloc(&ghealthRead, sizeof(int)*T);
    cudaMemcpy(gxcoord,xcoord,sizeof(int)*T,cudaMemcpyHostToDevice);
    cudaMemcpy(gycoord,ycoord,sizeof(int)*T,cudaMemcpyHostToDevice);
    myMemSetInt<<<1,1024>>>(gscore,0,T);
    myMemSetInt<<<1,1024>>>(ghealth,H,T);
    myMemSetInt<<<1,1024>>>(ghealthRead,H,T);
    myMemSetInt<<<1,1024>>>(distance,INT_MAX,T);
    
    


    //printing the health of tanks before war
    // int * host_health = (int *)malloc(sizeof(int)*T);
    // cudaMemcpy(host_health, ghealth, sizeof(int)*T, cudaMemcpyDeviceToHost);
    // printf("\n");
    // for(int i=0; i<T; i++){
    //     printf("%d ",host_health[i]);
    // }
    // printf("\n");

    int *tanksLeft;
    cudaMalloc(&tanksLeft,sizeof(int));
    myMemSetInt<<<1,1024>>>(tanksLeft,T,1);
    int CTanks[1]={T};
    int k=0;

    while(CTanks[0]>1)
    {
        k++;
        // if(k%T!=0) //Allowed by Rupesh Nasre Sir
        // {
            
            dtanks<<<T,T>>>(gxcoord, gycoord, gscore, ghealth, ghealthRead, T, N, distance, tanksLeft, k);
            // cudaDeviceSynchronize();
            
            
            // printf("\n");
            // printf("Round %d:\n", k);
            // cudaMemcpy(score,gscore,sizeof(int)*T,cudaMemcpyDeviceToHost);
            // printf("Score: ");
            // for(int i=0; i<T; i++) printf("%d ",score[i]);
            // printf("\n");
            // printf("Health: ");
            // cudaMemcpy(host_health,ghealth,sizeof(int)*T,cudaMemcpyDeviceToHost);
            // for(int i=0; i<T; i++) printf("%d ", host_health[i]);


            myMemSetInt<<<1,1024>>>(distance,INT_MAX,T);
            // cudaDeviceSynchronize();
            checktanks<<<1,T>>>(ghealth,tanksLeft);
            cudaMemcpy(&CTanks[0],tanksLeft,sizeof(int)*1,cudaMemcpyDeviceToHost);
            myMemSetInt<<<1,1024>>>(tanksLeft,T,1);
            cudaMemcpy(ghealthRead,ghealth,sizeof(int)*T,cudaMemcpyDeviceToDevice);
            // printf("%d ",CTanks[0]);
            cudaDeviceSynchronize();
        // }
    }
    
    cudaMemcpy(score,gscore,sizeof(int)*T,cudaMemcpyDeviceToHost);
    cudaDeviceSynchronize();


    // printf("\n");
    // for(int i=0; i<T; i++){
    //     printf("%d\n",score[i]);
    // }
    // printf("\n");
    //printing health after war
    // for(int i=0; i<T; i++){
    //     printf("%d ",host_health[i]);
    // }

    //*********************************
    // Your Code ends here (Do not change anything in main() below this comment)
    //********************************

    auto end  = chrono::high_resolution_clock::now();

    chrono::duration<double, std::micro> timeTaken = end-start;

    printf("Execution time : %f\n", timeTaken.count());

    // Output
    char *outputfilename = argv[2];
    char *exectimefilename = argv[3]; 
    FILE *outputfilepointer;
    outputfilepointer = fopen(outputfilename,"w");

    for(int i=0;i<T;i++)
    {
        fprintf( outputfilepointer, "%d\n", score[i]);
    }
    fclose(inputfilepointer);
    fclose(outputfilepointer);

    outputfilepointer = fopen(exectimefilename,"w");
    fprintf(outputfilepointer,"%f", timeTaken.count());
    fclose(outputfilepointer);

    free(xcoord);
    free(ycoord);
    free(score);
    cudaDeviceSynchronize();
    return 0;
}