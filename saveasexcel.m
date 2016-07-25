function saveasexcel(dir ,saveas, content)
    xlswrite(saveas, content)
    directory = strcat(dir, saveas);
   
    Excel = actxserver('Excel.Application');
    Excel.Workbooks.Open(directory);
    
    Range = Excel.Range('B4:E9');
    Range.NumberFormat = '0,0000';
    
    Range = Excel.Range('B12:B13');
    Range.NumberFormat = '0,00';
    
    Range = Excel.Range('B14:B16');
    Range.NumberFormat = '0,0000';
    
    Range = Excel.Range('B17:B18');
    Range.NumberFormat = '0';
    
    Range = Excel.Range('C:C');
    Range.ColumnWidth = 4.00;
    
    Range = Excel.Range('B19:B22');
    Range.Font.Bold = 1;
    
    Range = Excel.Range('B1');
    Range.Font.Bold = 1;
    
    Excel.Visible=1;