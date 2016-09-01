function distribution = dist(input)

 
    
    switch input
            case 0
                distribution = { 'normal'};
            case -1
                distribution = { 'constant'};
            case 1
                distribution = { 'lognormal'};
            case 2
                distribution = { 'Spike'};
            case 3
                distribution = { 'triangular'};
            case 4 
                distribution = { 'Weibull'};
            case 5
                distribution = { 'sinh-arcsinh'};
            case 6
                distribution = { 'Johnson Sb'};
            case 7
                distribution = { 'Johnson Su'};
     end 
   
    
end